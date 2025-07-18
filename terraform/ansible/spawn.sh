IP=$(curl -s ifconfig.me)
echo "[deploy-vm]" > inventory.ini
echo "$IP ansible_user=azureuser ansible_password=rootroot123! ansible_connection=ssh" >> inventory.ini