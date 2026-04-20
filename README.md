#  Projet Terraform AWS – Application PHP CRUD sécurisée avec WAF

##  Architecture globale

L’architecture mise en place est la suivante :

Utilisateur → ALB → EC2 (Apache + PHP + MariaDB)
↑
AWS WAF

###  Flux de fonctionnement

1. L’utilisateur accède à l’application via l’URL de l’ALB
2. Le trafic passe par AWS WAF (filtrage des attaques)
3. L’ALB redirige les requêtes vers l’instance EC2
4. EC2 exécute l’application PHP
5. Les données sont stockées dans MariaDB (local sur EC2)

---

##  Services AWS utilisés

### 🖥️ 1. EC2 (Amazon Elastic Compute Cloud)

Rôle :

* Héberger l’application PHP
* Exécuter Apache + PHP + MariaDB

 Configuration :

* AMI : Amazon Linux 2
* Instance : t3.micro
* Installation automatique via `user_data`
* Déploiement du code depuis GitHub

 Pourquoi EC2 ?

* Contrôle total sur l’environnement
* Facile à automatiser avec Terraform
* Adapté pour un projet pédagogique

---

###  2. Application Load Balancer (ALB)

 Rôle :

* Exposer l’application sur Internet
* Distribuer le trafic HTTP vers EC2

 Configuration :

* Port : 80 (HTTP)
* Target group lié à l’instance EC2
* Health check sur `/index.php`

 Pourquoi ALB ?

* Gestion du trafic HTTP
* Haute disponibilité
* Intégration native avec WAF

---

###  3. AWS WAF (Web Application Firewall)

 Rôle :

* Protéger l’application contre les attaques web

 Règles utilisées :

* `AWSManagedRulesCommonRuleSet`

 Protection contre :

* injections SQL
* XSS (Cross-Site Scripting)
* requêtes malveillantes

 Pourquoi WAF ?

* Sécurité gérée par AWS
* Facile à intégrer avec ALB
* Pas besoin de configurer un firewall complexe

---

###  4. Security Groups

Deux groupes de sécurité :

#### ALB Security Group

* Autorise HTTP (port 80) depuis Internet

#### EC2 Security Group

* Autorise HTTP depuis ALB uniquement
* Autorise SSH (port 22)

 Pourquoi ?

* Séparation des responsabilités
* Sécurité réseau renforcée

---

###  5. MariaDB (sur EC2)

Rôle :

* Stocker les données de l’application

 Configuration :

* Base : `blog`
* Utilisateur : `bloguser`
* Mot de passe sécurisé

 Pourquoi local ?

* Simplicité pour un projet académique
* Évite la complexité de RDS

---

##  Déploiement de l’application

Le déploiement est entièrement automatisé via `user_data` :

### Étapes exécutées automatiquement :

1. Installation des paquets :

   * Apache
   * PHP
   * MariaDB
   * Git

2. Démarrage des services

3. Création de la base de données

4. Clonage du projet GitHub :

```bash
git clone https://github.com/Mohamed-Hedi-Jemaa/Terraform-AWS.git
```

5. Copie des fichiers dans `/var/www/html`

6. Import du fichier SQL :

```bash
mysql -u root < articles.sql
```

7. Configuration dynamique de la base dans `db-config.php`



##  Structure du projet Terraform

```bash
terraform/
├── main.tf          # Infrastructure complète
├── variables.tf     # Déclaration des variables
├── terraform.tfvars # Valeurs des variables
├── outputs.tf       # Sorties (URL, IP...)
```



##  Commandes Terraform

### Initialisation

```bash
terraform init
```

### Planification

```bash
terraform plan
```

### Déploiement

```bash
terraform apply
```

### Destruction

```bash
terraform destroy
```



##  Accès à l’application

Après déploiement :

 URL :

```bash
pour moi je teste l'app sur :

http://crudphpwaf-alb-782024293.us-east-1.elb.amazonaws.com
```

 Outputs Terraform :

* `app_url`
* `alb_dns_name`
* `ec2_public_ip`



##  Points importants

* Le WAF protège uniquement via l’ALB
* Ne pas accéder directement à EC2 (sinon bypass du WAF)
* Les fichiers sensibles ne doivent pas être versionnés :

  * `.tfstate`
  * `.pem`




##  Conclusion

Ce projet démontre l’utilisation de Terraform pour déployer une infrastructure complète sur AWS en intégrant :

* calcul (EC2)
* réseau (ALB)
* sécurité (WAF)
* base de données

L’approche Infrastructure as Code permet :

* reproductibilité
* automatisation
* meilleure organisation
