import sys
import os
import json
import solcx

def generate_standard_json(contract_path):
    """
    فایل ورودی JSON استاندارد برای وریفای کردن قرارداد را با فرمت صحیح تولید می‌کند.
    """
    if not os.path.exists(contract_path):
        print(f"❌ خطا: فایل در مسیر '{contract_path}' پیدا نشد.")
        sys.exit(1)

    # --- تغییر کلیدی در این بخش است ---
    # ساختار settings دقیقاً مطابق با نیاز اکسپلوررها اصلاح شد.
    compiler_settings = {
        "optimizer": {
            "enabled": False, # این مقدار بر اساس نیاز شما می‌تواند true یا false باشد
            "runs": 200
        },
        "outputSelection": {
            "*": {
                "*": [
                    "abi",
                    "evm.bytecode",
                    "evm.deployedBytecode",
                    "evm.methodIdentifiers",
                    "metadata"
                ]
            }
        },
        "metadata": {
            "useLiteralContent": True
        },
        "libraries": {}
    }

    try:
        # خواندن محتوای فایل قرارداد
        with open(contract_path, 'r', encoding='utf-8') as f:
            source_code = f.read()

        # ساخت ساختار ورودی استاندارد JSON
        input_json = {
            "language": "Solidity",
            "sources": {
                contract_path: {
                    "content": source_code
                }
            },
            "settings": compiler_settings
        }

        # ساخت نام و مسیر فایل خروجی
        base_name = os.path.basename(contract_path)
        contract_name, _ = os.path.splitext(base_name)
        output_filename = f"{contract_name}-standard-input.json"
        output_dir = "verify-explorer-output"
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, output_filename)

        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(input_json, f, indent=2, ensure_ascii=False)
        
        print(f"✅ فایل '{output_path}' با موفقیت و با فرمت صحیح ساخته شد.")

    except Exception as e:
        print(f"❌ خطایی در هنگام ساخت فایل JSON رخ داد: {e}")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("❌ خطا: لطفاً مسیر فایل قرارداد سالیدیتی را به عنوان ورودی بدهید.")
        sys.exit(1)
    
    contract_file_path = sys.argv[1]
    generate_standard_json(contract_file_path)

if __name__ == "__main__":
    main()
