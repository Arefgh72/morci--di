import os
import sys
import json
import re
from web3 import Web3
import solcx

# --- ۱. بخش تنظیمات و اتصال به شبکه (تغییر یافته) ---

def setup(network_id):
    """
    اطلاعات شبکه را از فایل JSON می‌خواند و بر اساس ID ورودی به آن متصل می‌شود.
    """
    # نصب خودکار کامپایلر سالیدیتی
    try:
        solcx.install_solc(version='0.8.20')
        solcx.set_solc_version('0.8.20')
        print("✅ کامپایلر Solc آماده است.")
    except Exception as e:
        print(f"⚠️ خطایی در آماده‌سازی کامپایلر Solc رخ داد: {e}")
        sys.exit(1)

    # خواندن اطلاعات شبکه‌ها از فایل
    try:
        with open('networks.json', 'r') as f:
            networks = json.load(f)
    except FileNotFoundError:
        print("❌ خطا: فایل networks.json در ریشه پروژه پیدا نشد.")
        sys.exit(1)

    # پیدا کردن شبکه مورد نظر بر اساس ID
    selected_network = next((net for net in networks if net['id'] == network_id), None)
    
    if not selected_network:
        print(f"❌ خطا: شبکه‌ای با ID '{network_id}' در فایل networks.json پیدا نشد.")
        sys.exit(1)
        
    rpc_url = selected_network['rpc_url']
    print(f"🌍 در حال اتصال به شبکه: {selected_network['displayName']} ({rpc_url})")

    # خواندن کلید خصوصی از GitHub Secrets
    try:
        private_key = os.environ["PRIVATE_KEY"]
    except KeyError:
        print("❌ خطا: متغیر PRIVATE_KEY در GitHub Secrets پیدا نشد.")
        sys.exit(1)

    # اتصال به شبکه بلاکچین
    web3 = Web3(Web3.HTTPProvider(rpc_url))
    if not web3.is_connected():
        print(f"❌ خطا در اتصال به شبکه.")
        sys.exit(1)

    account = web3.eth.account.from_key(private_key)
    web3.eth.default_account = account.address

    print(f"✅ با موفقیت به شبکه متصل شد.")
    print(f"👤 آدرس دیپلوی کننده: {account.address}")
    
    return web3, account

# ... (بقیه توابع مثل resolve_args و execute_formula بدون تغییر باقی می‌مانند) ...
def resolve_args(args, context):
    """
    آرگومان‌ها را بررسی کرده و متغیرهایی مثل {{MyToken.address}} را با مقادیر واقعی جایگزین می‌کند.
    """
    resolved = []
    # الگوی پیدا کردن متغیرها: {{ContractName.address}}
    pattern = re.compile(r"\{\{([a-zA-Z0-9_]+)\.address\}\}")

    for arg in args:
        if isinstance(arg, str):
            match = pattern.match(arg)
            if match:
                contract_name = match.group(1)
                if contract_name in context and "address" in context[contract_name]:
                    resolved.append(context[contract_name]["address"])
                    print(f"🔄 متغیر '{arg}' با آدرس '{context[contract_name]['address']}' جایگزین شد.")
                else:
                    print(f"❌ خطا: آدرس قرارداد '{contract_name}' در مراحل قبلی پیدا نشد.")
                    sys.exit(1)
            else:
                resolved.append(arg)
        else:
            resolved.append(arg)
    return resolved

def execute_formula(web3, account, formula_path):
    """
    فایل دستورالعمل JSON را می‌خواند و مراحل آن را اجرا می‌کند.
    """
    try:
        with open(formula_path, 'r') as f:
            formula = json.load(f)
    except FileNotFoundError:
        print(f"❌ خطا: فایل دستورالعمل در مسیر '{formula_path}' پیدا نشد.")
        sys.exit(1)

    print(f"\n🚀 شروع اجرای دستورالعمل: {formula['name']}")
    
    # برای ذخیره آدرس و ABI قراردادهای دیپلوی شده
    deployment_context = {}

    for step in sorted(formula["steps"], key=lambda s: s['step']):
        action = step["action"]
        step_num = step["step"]
        contract_name = step["contractName"]
        
        print(f"\n--- اجرای مرحله {step_num}: '{action}' برای '{contract_name}' ---")

        if action == "deploy":
            source_path = step["source"]
            constructor_args = resolve_args(step.get("args", []), deployment_context)

            # کامپایل کردن قرارداد
            compiled_sol = solcx.compile_files([source_path], output_values=["abi", "bin"])
            contract_interface = compiled_sol[f'{source_path}:{contract_name}']
            abi = contract_interface['abi']
            bytecode = contract_interface['bin']
            
            # ساخت و ارسال تراکنش دیپلوی
            Contract = web3.eth.contract(abi=abi, bytecode=bytecode)
            tx = Contract.constructor(*constructor_args).build_transaction({
                "from": account.address,
                "nonce": web3.eth.get_transaction_count(account.address),
            })
            signed_tx = web3.eth.account.sign_transaction(tx, private_key=account.key)
            tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
            
            print(f"⏳ در حال دیپلوی قرارداد... هش تراکنش: {tx_hash.hex()}")
            tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
            
            contract_address = tx_receipt.contractAddress
            print(f"✅ قرارداد '{contract_name}' با موفقیت در آدرس {contract_address} دیپلوی شد.")
            
            # ذخیره اطلاعات برای مراحل بعدی
            deployment_context[contract_name] = {"address": contract_address, "abi": abi}

        elif action == "call_function":
            function_name = step["function"]
            function_args = resolve_args(step.get("args", []), deployment_context)
            
            # پیدا کردن اطلاعات قرارداد از مراحل قبلی
            if contract_name not in deployment_context:
                print(f"❌ خطا: قرارداد '{contract_name}' برای فراخوانی تابع، قبلا دیپلوی نشده است.")
                sys.exit(1)
            
            target_contract_info = deployment_context[contract_name]
            contract_instance = web3.eth.contract(address=target_contract_info["address"], abi=target_contract_info["abi"])
            
            # ساخت و ارسال تراکنش فراخوانی تابع
            func = getattr(contract_instance.functions, function_name)
            tx = func(*function_args).build_transaction({
                "from": account.address,
                "nonce": web3.eth.get_transaction_count(account.address),
            })
            signed_tx = web3.eth.account.sign_transaction(tx, private_key=account.key)
            tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)

            print(f"⏳ در حال فراخوانی تابع '{function_name}'... هش تراکنش: {tx_hash.hex()}")
            web3.eth.wait_for_transaction_receipt(tx_hash)
            print(f"✅ تابع '{function_name}' روی قرارداد '{contract_name}' با موفقیت اجرا شد.")
        
        else:
            print(f"⚠️ اکشن ناشناخته '{action}' در مرحله {step_num}. از این مرحله عبور می‌کنیم.")

    print(f"\n🎉 تمام مراحل دستورالعمل '{formula['name']}' با موفقیت انجام شد.")

# --- ۳. بخش اصلی برنامه (تغییر یافته) ---

def main():
    if len(sys.argv) < 3:
        print("❌ خطا: ورودی‌ها کامل نیستند.")
        print("مثال: python scripts/deploy.py <formula_file.json> <network_id>")
        sys.exit(1)
    
    formula_filename = sys.argv[1]
    network_id = sys.argv[2] # ورودی دوم برای ID شبکه
    
    formula_path = os.path.join("formulas", formula_filename)
    
    web3, account = setup(network_id) # ارسال ID شبکه به تابع setup
    execute_formula(web3, account, formula_path)

if __name__ == "__main__":
    main()
