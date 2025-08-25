import sys
import os
import json
import solcx

def generate_standard_json(contract_path):
    """
    فایل ورودی JSON استاندارد برای وریفای کردن قرارداد در Etherscan را تولید می‌کند.
    """
    if not os.path.exists(contract_path):
        print(f"❌ خطا: فایل در مسیر '{contract_path}' پیدا نشد.")
        sys.exit(1)

    # تنظیمات کامپایلر باید دقیقاً با تنظیمات زمان دیپلوی یکی باشد.
    # در اینجا ما از تنظیمات استاندارد با optimizer فعال استفاده می‌کنیم.
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
        # خواندن محتوای فایل قرارداد
        with open(contract_path, 'r') as f:
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

        # ذخیره فایل JSON خروجی
        output_filename = "verification_input.json"
        with open(output_filename, 'w') as f:
            json.dump(input_json, f, indent=4)
        
        print(f"✅ فایل '{output_filename}' با موفقیت برای قرارداد '{contract_path}' ساخته شد.")
        print("شما می‌توانید این فایل را از بخش 'Artifacts' در گیت‌هاب اکشن دانلود کنید.")

    except Exception as e:
        print(f"❌ خطایی در هنگام ساخت فایل JSON رخ داد: {e}")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("❌ خطا: لطفاً مسیر فایل قرارداد سالیدیتی را به عنوان ورودی بدهید.")
        print("مثال: python scripts/generate_verification_json.py contracts/MainContract.sol")
        sys.exit(1)
    
    contract_file_path = sys.argv[1]
    generate_standard_json(contract_file_path)

if __name__ == "__main__":
    main()
