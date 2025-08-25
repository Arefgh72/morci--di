import os
import sys
import json
import re
from web3 import Web3
import solcx
from web3.exceptions import Web3RPCError
import time

# --- ۱. بخش تنظیمات و اتصال ---

def setup(network_id):
    """
    اطلاعات شبکه را از JSON می‌خواند، به شبکه وصل شده و محیط را آماده می‌کند.
    """
    try:
        solcx.install_solc(version='0.8.20')
        solcx.set_solc_version('0.8.20')
        print("✅ کامپایلر Solc آماده است.")
    except Exception as e:
        print(f"⚠️ خطایی در آماده‌سازی کامپایلر Solc رخ داد: {e}")
        sys.exit(1)

    try:
        with open('networks.json', 'r') as f:
            networks = json.load(f)
    except FileNotFoundError:
        print("❌ خطا: فایل networks.json در ریشه پروژه پیدا نشد.")
        sys.exit(1)

    selected_network = next((net for net in networks if net['id'] == network_id), None)
    
    if not selected_network:
        print(f"❌ خطا: شبکه‌ای با ID '{network_id}' در فایل networks.json پیدا نشد.")
        sys.exit(1)
        
    rpc_url = selected_network['rpc_url']
    print(f"🌍 در حال اتصال به شبکه: {selected_network['displayName']} ({rpc_url})")

    try:
        private_key = os.environ["PRIVATE_KEY"]
    except KeyError:
        print("❌ خطا: متغیر PRIVATE_KEY در GitHub Secrets پیدا نشد.")
        sys.exit(1)

    web3 = Web3(Web3.HTTPProvider(rpc_url))
    if not web3.is_connected():
        print(f"❌ خطا در اتصال به شبکه.")
        sys.exit(1)

    account = web3.eth.account.from_key(private_key)
    web3.eth.default_account = account.address

    print(f"✅ با موفقیت به شبکه متصل شد.")
    print(f"👤 آدرس دیپلوی کننده: {account.address}")
    
    return web3, account

# --- ۲. موتور اجرایی ---

def resolve_args(args, context):
    """
    متغیرهای داخل آرگومان‌ها مانند {{ContractName.address}} را جایگزین می‌کند.
    """
    resolved = []
    pattern = re.compile(r"\{\{([a-zA-Z0-9_]+)\.address\}\}")

    for arg in args:
        if isinstance(arg, str):
            match = pattern.match(arg)
            if match:
                object_name = match.group(1)
                if object_name in context and "address" in context[object_name]:
                    resolved.append(context[object_name]["address"])
                    print(f"🔄 متغیر '{arg}' با آدرس '{context[object_name]['address']}' جایگزین شد.")
                else:
                    print(f"❌ خطا: آدرس برای '{object_name}' در کانتکست پیدا نشد.")
                    sys.exit(1)
            else:
                resolved.append(arg)
        else:
            resolved.append(arg)
    return resolved

def execute_formula(web3, account, formula_path):
    """
    فایل دستورالعمل JSON را با منطق پیشرفته nonce اجرا می‌کند.
    """
    try:
        with open(formula_path, 'r') as f:
            formula = json.load(f)
    except FileNotFoundError:
        print(f"❌ خطا: فایل دستورالعمل در مسیر '{formula_path}' پیدا نشد.")
        sys.exit(1)

    print(f"\n🚀 شروع اجرای دستورالعمل: {formula['name']}")
    
    deployment_context = {}
    deployment_context['deployer'] = {'address': account.address}
    print(f"🔧 کانتکست اولیه با آدرس دیپلوی‌کننده تنظیم شد.")

    for step in sorted(formula["steps"], key=lambda s: s['step']):
        action = step["action"]
        step_num = step["step"]
        
        print(f"\n--- اجرای مرحله {step_num}: '{action}' برای '{step['contractName']}' ---")
        
        # گرفتن جدیدترین nonce از شبکه برای شروع این مرحله
        current_nonce = web3.eth.get_transaction_count(account.address)
        print(f"⛓️ Nonce اولیه برای این مرحله: {current_nonce}")

        max_retries = 3
        for i in range(max_retries):
            try:
                # ساخت تراکنش با nonce فعلی
                if action == "deploy":
                    contract_name = step["contractName"]
                    source_path = step["source"]
                    constructor_args = resolve_args(step.get("args", []), deployment_context)
                    compiled_sol = solcx.compile_files([source_path], output_values=["abi", "bin"])
                    contract_interface = compiled_sol[f'{source_path}:{contract_name}']
                    abi = contract_interface['abi']
                    bytecode = contract_interface['bin']
                    Contract = web3.eth.contract(abi=abi, bytecode=bytecode)
                    tx_data = Contract.constructor(*constructor_args).build_transaction({
                        "from": account.address, "nonce": current_nonce
                    })

                elif action == "call_function":
                    contract_name = step["contractName"]
                    function_name = step["function"]
                    function_args = resolve_args(step.get("args", []), deployment_context)
                    target_contract_info = deployment_context[contract_name]
                    contract_instance = web3.eth.contract(address=target_contract_info["address"], abi=target_contract_info["abi"])
                    func = getattr(contract_instance.functions, function_name)
                    tx_data = func(*function_args).build_transaction({
                        "from": account.address, "nonce": current_nonce
                    })
                else:
                    print(f"⚠️ اکشن ناشناخته '{action}'.")
                    break

                # امضا و ارسال
                signed_tx = web3.eth.account.sign_transaction(tx_data, private_key=account.key)
                tx_hash = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
                print(f"⏳ تراکنش با Nonce {current_nonce} ارسال شد... هش: {tx_hash.hex()}")
                
                # انتظار برای تایید
                tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash, timeout=300)

                # ثبت نتیجه در صورت موفقیت
                if action == "deploy":
                    contract_address = tx_receipt.contractAddress
                    print(f"✅ قرارداد '{contract_name}' با موفقیت در آدرس {contract_address} دیپلوی شد.")
                    deployment_context[contract_name] = {"address": contract_address, "abi": abi}
                elif action == "call_function":
                    print(f"✅ تابع '{function_name}' روی قرارداد '{contract_name}' با موفقیت اجرا شد.")
                
                break # <-- خروج از حلقه تلاش مجدد در صورت موفقیت

            except Web3RPCError as e:
                # اگر خطای nonce بود، nonce را یکی بالا ببر و دوباره امتحان کن
                error_message = str(e).lower()
                if ('nonce too low' in error_message or 'replacement transaction underpriced' in error_message):
                    print(f"⚠️ خطای Nonce با شماره {current_nonce} دریافت شد. تلاش مجدد با شماره بعدی...")
                    current_nonce += 1 # افزایش دستی nonce برای تلاش مجدد
                    if i == max_retries - 1: # اگر آخرین تلاش بود، خطا را نمایش بده و خارج شو
                        raise e
                    time.sleep(1) # یک ثانیه تاخیر قبل از تلاش مجدد
                else: # اگر خطای دیگری بود، فوراً خارج شو
                    raise e
            except Exception as e: # برای خطاهای دیگر
                print(f"❌ یک خطای پیش‌بینی نشده رخ داد.")
                raise e

    print(f"\n🎉 تمام مراحل دستورالعمل '{formula['name']}' با موفقیت انجام شد.")

# --- ۳. برنامه اصلی ---

def main():
    if len(sys.argv) < 3:
        print("❌ خطا: ورودی‌ها کامل نیستند.")
        sys.exit(1)
    
    formula_filename = sys.argv[1]
    network_id = sys.argv[2]
    
    formula_path = os.path.join("formulas", formula_filename)
    
    web3, account = setup(network_id)
    execute_formula(web3, account, formula_path)

if __name__ == "__main__":
    main()
