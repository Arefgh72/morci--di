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

    # تشخیص پشتیبانی EIP-1559
    try:
        latest_block = web3.eth.get_block('latest')
        supports_eip1559 = 'baseFeePerGas' in latest_block
        print(f"🔹 EIP-1559 پشتیبانی می‌شود؟ {supports_eip1559}")
    except Exception:
        supports_eip1559 = False

    print(f"✅ با موفقیت به شبکه متصل شد.")
    print(f"👤 آدرس دیپلوی کننده: {account.address}")
    
    return web3, account, supports_eip1559

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

def execute_formula(web3, account, formula_path, supports_eip1559):
    """
    فایل دستورالعمل JSON را اجرا می‌کند با منطق هوشمند nonce و gas و پشتیبانی EIP-1559.
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
        time.sleep(5)
        
        current_nonce = web3.eth.get_transaction_count(account.address)
        print(f"⛓️ Nonce اولیه برای این مرحله: {current_nonce}")

        max_retries = 3
        for i in range(max_retries):
            try:
                gas_price = web3.eth.gas_price
                gas_price_aggressive = int(gas_price * 1.2) # 20% بالاتر

                tx_options = {
                    "from": account.address,
                    "nonce": current_nonce,
                }

                # اگر شبکه EIP-1559 دارد
                if supports_eip1559:
                    latest_block = web3.eth.get_block('latest')
                    base_fee = latest_block['baseFeePerGas']
                    max_priority_fee = web3.to_wei(2, 'gwei')  # پیش‌فرض 2 Gwei
                    tx_options['maxFeePerGas'] = base_fee + max_priority_fee
                    tx_options['maxPriorityFeePerGas'] = max_priority_fee
                    print(f"💰 EIP-1559 فعال: maxFee={tx_options['maxFeePerGas']}, maxPriority={max_priority_fee}")
                else:
                    tx_options['gasPrice'] = gas_price_aggressive
                    print(f"💰 شبکه Legacy: gasPrice={web3.from_wei(gas_price_aggressive, 'gwei')} Gwei")

                # Gas Limit
                if "gasLimit" in step:
                    tx_options['gas'] = step['gasLimit']
                    print(f"⛽️ از گاز لیمیت دستی استفاده می‌شود: {step['gasLimit']}")
                
                # ساخت تراکنش
                if action == "deploy":
                    contract_name = step["contractName"]
                    source_path = step["source"]
                    constructor_args = resolve_args(step.get("args", []), deployment_context)
                    compiled_sol = solcx.compile_files(
                        [source_path],
                        output_values=["abi", "bin"],
                        evm_version='istanbul'  # سازگار با شبکه‌های قدیمی
                    )
                    contract_interface = compiled_sol[f'{source_path}:{contract_name}']
                    abi = contract_interface['abi']
                    bytecode = contract_interface['bin']
                    Contract = web3.eth.contract(abi=abi, bytecode=bytecode)
                    
                    # Gas تخمینی برای Deploy
                    if "gasLimit" not in step:
                        estimated_gas = Contract.constructor(*constructor_args).estimate_gas({'from': account.address})
                        tx_options['gas'] = int(estimated_gas * 1.3)
                        print(f"⛽️ Gas تخمینی برای Deploy: {tx_options['gas']}")

                    tx_data = Contract.constructor(*constructor_args).build_transaction(tx_options)

                elif action == "call_function":
                    contract_name = step["contractName"]
                    function_name = step["function"]
                    function_args = resolve_args(step.get("args", []), deployment_context)
                    target_contract_info = deployment_context[contract_name]
                    contract_instance = web3.eth.contract(address=target_contract_info["address"], abi=target_contract_info["abi"])
                    func = getattr(contract_instance.functions, function_name)
                    
                    tx_data = func(*function_args).build_transaction(tx_options)
                else:
                    print(f"⚠️ اکشن ناشناخته '{action}'.")
                    break

                # امضا و ارسال
                signed_tx = web3.eth.account.sign_transaction(tx_data, private_key=account.key)
                tx_hash = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
                print(f"⏳ تراکنش با Nonce {current_nonce} ارسال شد... هش: {tx_hash.hex()}")
                
                # انتظار برای تایید
                tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash, timeout=300)

                # ثبت نتیجه
                if action == "deploy":
                    contract_address = tx_receipt.contractAddress
                    print(f"✅ قرارداد '{contract_name}' با موفقیت در آدرس {contract_address} دیپلوی شد.")
                    deployment_context[contract_name] = {"address": contract_address, "abi": abi}
                elif action == "call_function":
                    print(f"✅ تابع '{function_name}' روی قرارداد '{contract_name}' با موفقیت اجرا شد.")
                
                break  # اگر موفق بود، retry را رد می‌کنیم

            except Web3RPCError as e:
                error_message = str(e).lower()
                if ('nonce too low' in error_message or 'replacement transaction underpriced' in error_message):
                    print(f"⚠️ خطای Nonce با شماره {current_nonce} دریافت شد. تلاش مجدد با شماره بعدی...")
                    current_nonce += 1
                    if i == max_retries - 1:
                        raise e
                    time.sleep(5)
                else:
                    raise e
            except Exception as e:
                print(f"❌ یک خطای پیش‌بینی نشده رخ داد.")
                raise e

    print(f"\n🎉 تمام مراحل دستورالعمل '{formula['name']}' با موفقیت انجام شد.")

# --- ۳. برنامه اصلی ---

def main():
    if len(sys.argv) < 3:
        print("❌ خطا: ورودی‌ها کامل نیستند. فرمت صحیح: python deploy.py <formula_filename.json> <network_id>")
        sys.exit(1)
    
    formula_filename = sys.argv[1]
    network_id = sys.argv[2]
    
    formula_path = os.path.join("formulas", formula_filename)
    
    web3, account, supports_eip1559 = setup(network_id)
    execute_formula(web3, account, formula_path, supports_eip1559)

if __name__ == "__main__":
    main()
