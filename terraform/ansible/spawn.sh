echo "[web]" > inventory.ini
echo "$(terraform output -raw webapp_vm_ip) ansible_user=azureuser ansible_password=yourpassword ansible_connection=ssh" >> inventory.ini