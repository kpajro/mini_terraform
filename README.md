<h1>Projet Infrastructure Terraform + Ansible</h1>
<p>Ce projet déploie automatiquement une application Node.js sur une machine virtuelle Ubuntu hébergé avec Microsoft Azure en utilisant L'outil <b>Terraform</b> et <b>Ansible</b>.</p>

<h2><b>La structure de fichier du Terraform</b></h2>
<ul>
  <li>main.tf - La configuration principale de l'infrastructure</li>
  <li>variables.tf - Les variables réutilisables</li>
  <li>outputs.tf - Les valeurs exploitables</li>
  <li>provider.tf - Le provider</li>
  <li>terraform.tfvars - Les valeurs confidentielles</li>
</ul>

<h2>Prérequis</h2>
<p>Terraform - <a href="https://developer.hashicorp.com/terraform/install">https://developer.hashicorp.com/terraform/install</a></p>
<p>Génération d'une clé SSH RSA - ssh-keygen -t rsa -b 4096 -f C:\Users\[nom_pc]\.ssh\terraform_key -N ""</p>
<p>Mot de passe - rootroot123!</p>

<h2>Lancement de l'Infrastructure</h2>
<p>Dans le dossier Terraform, lancez la commande suivante : <code>terraform init</code> pour initialiser le dossier terraform, ensuite lancez la commande : <code>terraform plan</code> pour verifier et planifier l'infrastructure, enfin lancez la commande : <code>terraform apply</code> pour commencer l'assemblage de l'infrastructure</p>

<h3><b>Note :</b></h3>
<p>Si jamais l'appli rencontre un problème, juste relancer la commande <code>terraform apply</code></p>

