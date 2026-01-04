import hmac
import hashlib
import json
import requests
import sys

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 test_webhook.py <LOCAL_DOMAIN> <WEBHOOK_SECRET> [APP_NAME] [IMAGE] [DB_REQUIRED] [DB_ENV_MAPPING]")
        sys.exit(1)

    domain = sys.argv[1]
    secret = sys.argv[2]
    
    app_name = sys.argv[3] if len(sys.argv) > 3 else "hello-world"
    image = sys.argv[4] if len(sys.argv) > 4 else "nginxdemos/hello"
    db_required = sys.argv[5] if len(sys.argv) > 5 else "false"
    db_env_mapping = sys.argv[6] if len(sys.argv) > 6 else ""

    webhookUrl = f"https://hooks.{domain}/hooks/deploy-app"
    
    # 1. Prepare Payload
    payload = {"image": image}
    payload_json = json.dumps(payload)
    
    # 2. Calculate Signature (HMAC SHA256)
    signature = hmac.new(
        key=secret.encode(),
        msg=payload_json.encode(),
        digestmod=hashlib.sha256
    ).hexdigest()
    
    # 3. Construct URL with Query Params
    url = f"{webhookUrl}?app_name={app_name}&db_required={db_required}"
    if db_env_mapping:
        url += f"&db_env_mapping={db_env_mapping}"
    
    # 4. Send Request
    headers = {
        "Content-Type": "application/json",
        "X-Hub-Signature-256": signature
    }
    
    print(f"Sending webhook to: {url}")
    print(f"Payload: {payload_json}")
    print(f"Signature: {signature}")
    
    try:
        response = requests.post(url, data=payload_json, headers=headers, verify = False)
        print(f"\nResponse Code: {response.status_code}")
        print(f"Response Body: {response.text}")
    except Exception as e:
        print(f"\nError sending request: {e}")

if __name__ == "__main__":
    main()

