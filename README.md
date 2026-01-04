# Wondrax Platform

## Overview
The Wondrax Platform is a streamlined, self-hosted infrastructure solution designed to host containerized applications on a single Virtual Machine. It prioritizes automation, security, and ease of maintenance, making it ideal for continuous deployment workflows.

**Platform Goal**: To build an automated, low-maintenance, production-ready, and secure environment on a single VM to host container applications that are continuously updated (e.g., via Github Actions).

### Functional Domains
The platform provides a comprehensive set of capabilities organized into the following domains:

*   **System Initialization & Hardening**: Prepares a secure and production-ready operating system environment, including firewall configuration, automatic updates, and essential system utilities.
*   **Container Runtime Environment**: Establishes a robust Docker and Docker Compose infrastructure to host and manage containerized applications efficiently.
*   **Traffic Routing & Security (Ingress)**: Manages incoming traffic via Traefik as a dynamic reverse proxy, ensuring secure (TLS/SSL) and load-balanced access to services.
*   **Deployment Automation (CI/CD)**: Facilitates continuous delivery by listening for webhooks from CI pipelines and automatically updating applications without downtime.
*   **Observability & Monitoring**: Provides real-time insights into system health and performance using Netdata, with integrated alerting to notification channels like Discord.
*   **Data Management & Persistence**: Offers a shared, managed PostgreSQL database service and secure secrets management for applications.
*   **Backup & Disaster Recovery**: Ensures data integrity through automated daily backups of databases and volumes, securely synchronized to offsite cloud storage (Google Drive).


### GCP Service Account for Backup Location
Um ein GCP Service Account zu erstellen und die Backup Location zu konfigurieren, folge diesen Schritten:

1. Login via `gcloud auth application-default login`
2. Create terraform.tfvars and adjust to correct values: 
    ```hcl
    # terraform.tfvars

    project_id  = "dein-echtes-projekt-id-12345"
    bucket_name = "dein-echter-unique-bucket-name"
    region      = "europe-west3"
    ```
    Bash Command: 
    ```bash
    cat <<EOF > terraform/terraform.tfvars
    # terraform.tfvars

    project_id  = "dein-echtes-projekt-id-12345"
    bucket_name = "dein-echter-unique-bucket-name"
    region      = "europe-west3"
    EOF
    ```

3. Make *create_backup_and_sa.sh* executable: `chmod +x ./scripts/create_backup_and_sa.sh`

### Setup Domain and Subdomains

#### Checkdomain

Checkdomain is fully supported by Traefik (via the underlying library "lego


Retrieve API Token from *checkdomain* and but it into `secrets.yml` to the key `CHECKDOMAIN_API_TOKEN`.

### Secrets & Credentials

The platform uses a `secrets.yml` file to store sensitive information. Copy `secrets-template.yml` to `secrets.yml` and populate it with your values.

**Traefik Dashboard Authentication (`traefik_dashboard_auth`)**
The `traefik_dashboard_auth` variable requires a password hash in the `htpasswd` format (user:hash).
To generate a new password for the `admin` user:

1.  **Using `htpasswd`:**
    ```bash
    htpasswd -nb admin your_password
    ```
2.  **Using `openssl` (if `htpasswd` is not available):**
    ```bash
    echo -n "admin:$(openssl passwd -apr1 your_password)"
    ```

For the hashing mechanism for the portainer password `passlib` library is used. Installing it might be neccessary: `sudo apt install python3-passlib`

### Local Test Environment

Follow these steps to spin up a local Ubuntu VM and deploy the platform using Ansible.

**Prerequisites:**
- [Multipass](https://multipass.run/) installed.
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed.

1. **Launch VM:**
    Create a new Ubuntu instance.
    ```bash
    multipass launch --name ansible-sandbox --cpus 2 --memory 2G --disk 10G
    ```

2. **Configure SSH Access:**
    Copy your public SSH key to the VM to allow Ansible to connect without a password.
    ```bash
    multipass exec ansible-sandbox -- bash -c "echo '$(cat ~/.ssh/id_rsa.pub)' >> ~/.ssh/authorized_keys"
    ```

3. **Get VM IP Address:**
    Retrieve the IP address of your new VM.
    ```bash
    multipass info ansible-sandbox
    ```
    *Note the IPv4 address (e.g., `192.168.64.2`) for step 5.*

4. **Prepare Secrets:**
    Create a `secrets.yml` file from the template.
    ```bash
    cp secrets-template.yml secrets.yml
    ```
    *You can edit `secrets.yml` to set custom passwords or tokens, but the defaults work for testing.*

5. **Deploy with Ansible:**
    Run the playbook targeting your local VM. Replace `<VM_IP>` with the IP from step 3.

    ```bash
    # Create a temporary inventory file
    echo "[server]" > inventory.ini
    echo "<VM_IP> ansible_user=ubuntu" >> inventory.ini

    # Run the playbook
    ansible-playbook -i inventory.ini setup-platform.yml -e "env=local"
    ```
    The `env=local` flag ensures that local **self-signed certificates** are generated for Traefik.


6.  **Add domains to your hosts file:**
    Change `/etc/hosts` and add this line. This includes the infrastructure subdomains **and** the subdomain for the test application (`hello-world`).
    ```
    <VM_IP>   traefik.<YOUR_PLATTFORM_DOMAIN> 
    <VM_IP>   portainer.<YOUR_PLATTFORM_DOMAIN> 
    <VM_IP>   monitor.<YOUR_PLATTFORM_DOMAIN> 
    <VM_IP>   hooks.<YOUR_PLATTFORM_DOMAIN>
    <VM_IP>   hello-world.<YOUR_PLATTFORM_DOMAIN>
    <VM_IP>   postgrest.<YOUR_PLATTFORM_DOMAIN>
    ```

7.  **Verify Platform Services:**
    Open your browser and verify that the management services are reachable and secured with Basic Auth:
    - Traefik Dashboard: `https://traefik.<YOUR_PLATTFORM_DOMAIN>/dashboard/`
    - Portainer: `https://portainer.<YOUR_PLATTFORM_DOMAIN>`
    - Netdata: `https://monitor.<YOUR_PLATTFORM_DOMAIN>`

8.  **Test Deployment Webhook:**
    Use the provided Python script to test the webhook and deploy a sample application ("Hello World").
    
    You need the `webhook_secret` from your `secrets.yml`.
    ```bash
    python3 scripts/test_webhook.py <YOUR_PLATTFORM_DOMAIN> <YOUR_WEBHOOK_SECRET>
    ```
    *This script sends a signed request to the webhook, which will deploy an Nginx container. After a few seconds, it should be available at `https://hello-world.<YOUR_PLATTFORM_DOMAIN>`.*

9.  **Test Deployment Webhook with PostgREST (Database + Env Mapping):**
    You can also deploy an application that requires a specific database configuration, like **PostgREST**. This demonstrates how to map the auto-generated database credentials to the environment variables expected by the application.

    Ensure you add `postgrest.<YOUR_PLATTFORM_DOMAIN>` to your `/etc/hosts`.

    ```bash
    python3 scripts/test_webhook.py <YOUR_PLATTFORM_DOMAIN> <YOUR_WEBHOOK_SECRET> \
      postgrest \
      postgrest/postgrest \
      true \
      PGRST_DB_URI=DATABASE_URL,PGRST_DB_ANON_ROLE=DB_USER
    ```
    *This command tells the webhook to:*
    *   *Deploy `postgrest/postgrest` as `postgrest`.*
    *   *Create a Postgres user/database (`true` flag).*
    *   *Map the generated `DATABASE_URL` to `PGRST_DB_URI` and `DB_USER` to `PGRST_DB_ANON_ROLE`.*

    *Verify at `https://postgrest.<YOUR_PLATTFORM_DOMAIN>`. You should see the OpenAPI documentation or a JSON response.*

10. **Cleanup (Optional):**
    To stop and remove the test VM:
    ```bash
    multipass delete ansible-sandbox && multipass purge
    ```

    Remove the added line from the hosts file


### Deployment Webhook Documentation

The platform exposes a webhook endpoint to trigger application deployments. This is typically invoked by a CI/CD pipeline (e.g., GitHub Actions).

**Endpoint:** `POST https://hooks.<YOUR_PLATTFORM_DOMAIN>/hooks/deploy-app`

**Authentication:** 
The request must be signed using the `X-Hub-Signature-256` header, calculated using the `webhook_secret` from your `secrets.yml`.

**Query Parameters:**

| Parameter | Required | Description | Default |
| :--- | :--- | :--- | :--- |
| `app_name` | Yes | The unique name of the application (used for container name and subdomain). | - |
| `db_required` | No | Set to `true` to provision a PostgreSQL user and database for this app. | `false` |
| `db_env_mapping` | No | A comma-separated list of `TARGET_VAR=SOURCE_VAR` mappings to inject database credentials into the container. | (See below) |

**JSON Payload:**

```json
{
  "image": "ghcr.io/username/repository:latest"
}
```

**Database Environment Variables & Mapping (`db_env_mapping`)**

When `db_required=true`, the platform generates unique credentials (`DB_USER`, `DB_PASS`, `DB_NAME`, `DB_HOST`). You can control how these are exposed to your container:

1.  **Default Behavior (No mapping provided):**
    The platform automatically injects the standard PostgreSQL environment variables:
    *   `POSTGRES_HOST`
    *   `POSTGRES_DB`
    *   `POSTGRES_USER`
    *   `POSTGRES_PASSWORD`
    *   `DATABASE_URL` (Connection string)

2.  **Custom Mapping:**
    If your application expects different variable names (e.g., `MY_APP_DB_USER`), use the `db_env_mapping` parameter.
    
    **Format:** `TARGET_VAR=SOURCE_VAR,TARGET_VAR2=SOURCE_VAR2`
    
    **Available Source Variables:**
    *   `DB_USER`
    *   `DB_PASS`
    *   `DB_NAME`
    *   `DB_HOST`
    *   `DATABASE_URL`

    **Example:**
    To map `DB_USER` to `MY_APP_USER` and `DB_PASS` to `MY_APP_SECRET`:
    `?db_env_mapping=MY_APP_USER=DB_USER,MY_APP_SECRET=DB_PASS`


**Example: Github Action Workflow**

```yaml
- name: Trigger Deployment Webhook
  uses: distributhor/workflow-webhook@v3
  with:
    # Die URL inkl. deiner Parameter (app_name, db_required)
    webhook_url: "https://hooks.{{ env.PLATTFORM_DOMAIN }}/hooks/deploy-app?app_name=${{ env.APP_NAME }}&db_required=${{ env.DB_REQUIRED }}"
    
    # Das Secret zum Signieren (kommt aus GitHub Secrets)
    webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
    
    # Der JSON Payload (das Docker Image)
    data: '{"image": "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest"}'
```

### Monitoring

Monitoring mit Netdata (https://monitor.[PLATTFORM_DOMAIN])