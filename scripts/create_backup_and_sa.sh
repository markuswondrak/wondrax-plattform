#!/bin/bash
set -e # Bricht ab, wenn ein Befehl fehlschlägt

# Pfade definieren
TF_DIR="google-backup"
SECRETS_FILE="secrets.yml"
TEMPLATE_FILE="secrets-template.yml"
KEY_FILE="$TF_DIR/gcs-key.json"
VAULT_PASS_FILE=".vault_pass_temp"

echo "--- 1. Starte Terraform ---"
cd $TF_DIR
terraform apply -auto-approve
cd ..

if [ ! -f "$KEY_FILE" ]; then
    echo "Fehler: $KEY_FILE wurde nicht gefunden. Terraform fehlgeschlagen?"
    exit 1
fi

echo "--- 2. Ansible Vault Vorbereitung ---"
# Prüfen, ob secrets.yml existiert, sonst erstellen wir ein leeres Template
if [ ! -f "$SECRETS_FILE" ]; then
    echo "secrets.yml existiert nicht. Erstelle neue Datei aus Template..."
    if [ -f "$TEMPLATE_FILE" ]; then
        cp "$TEMPLATE_FILE" "$SECRETS_FILE"
    else
        echo "Warnung: $TEMPLATE_FILE nicht gefunden. Erstelle minimales File."
        echo "gdrive_sa_json: ''" > $SECRETS_FILE
    fi
    # Wir verschlüsseln sie initial, damit der Ablauf unten konsistent ist
    echo "Bitte gib ein neues Vault-Passwort ein:"
    ansible-vault encrypt $SECRETS_FILE
fi

# Passwort abfragen und temporär speichern (sicherer als Argumente)
echo -n "Bitte Ansible Vault Passwort eingeben: "
read -s VAULT_PASS
echo
echo "$VAULT_PASS" > $VAULT_PASS_FILE

echo "--- 3. Secrets aktualisieren ---"

# Entschlüsseln
ansible-vault decrypt $SECRETS_FILE --vault-password-file $VAULT_PASS_FILE --output "$SECRETS_FILE.tmp"

# Python nutzen, um JSON sauber in YAML einzubetten (verhindert Einrückungsfehler)
python3 -c "
import yaml

# Dateien laden
with open('$SECRETS_FILE.tmp', 'r') as f:
    secrets = yaml.safe_load(f) or {}

with open('$KEY_FILE', 'r') as f:
    key_content = f.read()

# Wert aktualisieren
secrets['gdrive_sa_json'] = key_content

# Speichern (mit Block-Style für bessere Lesbarkeit wäre komplexer, 
# safe_dump sorgt aber für valides YAML)
with open('$SECRETS_FILE.tmp', 'w') as f:
    yaml.safe_dump(secrets, f, default_flow_style=False, sort_keys=False)
"

# Das temporäre entschlüsselte File wieder verschlüsseln und das Original ersetzen
ansible-vault encrypt "$SECRETS_FILE.tmp" --vault-password-file $VAULT_PASS_FILE --output $SECRETS_FILE

# Aufräumen
rm $VAULT_PASS_FILE "$SECRETS_FILE.tmp"

echo "--- Fertig! Key wurde erfolgreich in $SECRETS_FILE übertragen. ---"