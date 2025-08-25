import sys
import os
import json
import solcx

def generate_standard_json(contract_path):
    """
    فایل ورودی JSON استاندارد برای وریفای کردن قرارداد را در پوشه و با نام مشخص تولید می‌کند.
    """
    if not os.path.exists(contract_path):
        print(f"❌ خطا: فایل در مسیر '{contract_path}' پیدا نشد.")
        sys.exit(1)

    compiler_settings = {
        "optimizer": {
            "enabled": True,
            "runs": 200
        },
        "outputSelection": {
            "*": {
                "*": ["*"]
            }
        }
    }

    try:
        with open(contract_path, 'r') as f:
            source_code = f.read()

        input_json = {
            "language": "Solidity",
            "sources": {
                contract_path: {
                    "content": source_code
                }
            },
            "settings": compiler_settings
        }

        # --- تغییرات اصلی در این بخش است ---
        # 1. ساخت نام فایل خروجی بر اساس نام فایل ورودی
        base_name = os.path.basename(contract_path)  # e.g., "MainContract.sol"
        contract_name, _ = os.path.splitext(base_name)  # e.g., "MainContract"
        output_filename = f"{contract_name}-standard-input.json"

        # 2. تعریف و ساخت پوشه خروجی
        output_dir = "verify-explorer-output"
        os.makedirs(output_dir, exist_ok=True) # پوشه را می‌سازد و اگر از قبل باشد خطا نمی‌دهد

        # 3. ساخت مسیر کامل فایل خروجی
        output_path = os.path.join(output_dir, output_filename)

        with open(output_path, 'w') as f:
            json.dump(input_json, f, indent=4)
        
        print(f"✅ فایل '{output_path}' با موفقیت ساخته شد.")
        print("شما می‌توانید این فایل را از بخش 'Artifacts' در گیت‌هاب اکشن دانلود کنید.")

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
