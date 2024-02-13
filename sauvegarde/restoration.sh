#!/bin/bash

# script écrit par RUFFENACH Timothée
# Le 13/02/2024

# Variables pour les chemins et fichier
journalisationChemin=/var/log/sauvegarde/
journalisationFichier=/var/log/sauvegarde/restoration.log
partageWindows=/sauveBDD
cheminWindows=/media/sauvegarde

#Variables commande
erreur=""
etatSignature=""
sortieStandard=""
password=""

# Vérifie si le chemin var/log/sauvegarde/existe
if [ ! -d "$journalisationChemin" ]; then
	# création s'il n'existe pas
	mkdir -p "$journalisationChemin"
fi

# fonction journalisation des erreurs
logErreur() {
	if [ -n "$erreur" ]; then
		echo "$horoDatage Erreur : $erreur" >> $journalisationFichier
		echo "Un erreur est survenue veuillez consulter le fichier $journalisationFichier"
		umount -l $cheminWindows
		exit 1
	fi
	erreur=""
}

# récupère date actuel
prendDate(){
	horoDatage=$(date +'%H:%M:%S %d-%m-%Y ')
}

# écrit chaine caractère dans long
ecritChaine(){
	prendDate
	echo $horoDatage $1 >> $journalisationFichier
}

commandeLog(){
	prendDate
	eval "$1 2> /tmp/error.txt 1> /tmp/output.txt"
	
	erreur=$(cat "/tmp/error.txt")

	sortieStandard=$(cat "/tmp/output.txt")
	logErreur

	#effacement output et error.txt
	rm /tmp/error.txt 
	rm /tmp/output.txt
}

aide(){
	ecritChaine "mode aide"
	echo "-h et --help affiche l'aide"
}

verificationSignature(){
	ecritChaine "Vérification signature"
	commandeLog "sha256sum -c $1 | grep -o 'OK'"

	if [ $sortieStandard = "OK" ]; then
		sortieStandard=""
	else
		echo "La signature ne correspond pas, veuillez effacer ou analyser le fichier"
		ecritChaine "ERREUR : la signature ne correspond pas"
		exit 1
	fi

}

# Vérifier si on est en mode test, help ou normal
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	aide
	exit
else
	ecritChaine "mode normal"
	echo "Mode normal"
fi

# montage du répertoire
ecritChaine "Montage de sauveBDD"
commandeLog "mount -t cifs //192.168.60.233$partageWindows /media/sauvegarde/ -o username=sauvegardebdd,password=azerty1234*,rw"

# créatation et gestion menu
fichiersCrypt=("$cheminWindows"/*.crypt)

#Vérification s'il exite de fichier .crypt
ecritChaine "Vérification fichier .crypt"
if [ ${#fichiersCrypt[@]} -eq 0 ]; then
	ecritChaine "ERREUR : Aucun fichier avec l'extension '.crypt'"
	echo "Aucun fichier avec l'extension '.crypt'"
	exit 1
fi

# Liste les fichier
ecritChaine "Liste les fichiers .crypt"

for fichier in "${fichiersCrypt[@]}"; do
	echo " - $(basename "$fichier")"
done

# saisie utilisateur
ecritChaine "Saisie utilisateur"
read -p "Veuillez entrez le nom du fichier : " choix

#vérifcation saisie
ecritChaine "Vérification saisie"
if [ -e "$cheminWindows/$choix" ]; then
	echo "Fichier selectionné : $choix"
else
	ecritChaine "ERREUR : fichier introuvable ou mauvaise saisie"
	echo "Le fichier n'existe pas ou la saisie n'est pas correcte."
	exit 1
fi

# on change l'extension
choix="${choix/.crypt/.sig}"
cheminFichier="$cheminWindows/$choix"

# Vérifation
verificationSignature $cheminFichier

# saisie du mot de passe
ecritChaine "Saisie du mot de passe"
echo -n "Veuillez saisir votre mot de passe : " 
read -s password
echo ""

fichierTarGz="${choix/.sig/.tar.gz}"
fichierCrypt="${choix/.sig/.crypt}"

ecritChaine "Déchiffrement"
commandeLog "echo '$password' | gpg --batch -q --yes --passphrase-fd 0 --output '$cheminWindows/$fichierTarGz' --decrypt '$cheminWindows/$fichierCrypt'"

# extraire
ecritChaine "Extraction tar.gz"
commandeLog "tar -xf $cheminWindows/$fichierTarGz --absolute-names $cheminWindows"

# Liste les fichier
ecritChaine "Liste les fichiers .sql"

# créatation et gestion menu
fichiersCrypt=("$cheminWindows"/*.sql)

for fichier in "${fichiersCrypt[@]}"; do
	echo " - $(basename "$fichier")"
done

# saisie utilisateur
ecritChaine "Saisie utilisateur"
read -p "Veuillez entrez le nom du fichier : " choix

#vérifcation saisie
ecritChaine "Vérification saisie"
if [ -e "$cheminWindows/$choix" ]; then
	echo "Fichier selectionné : $choix"
else
	ecritChaine "ERREUR : fichier introuvable ou mauvaise saisie"
	echo "Le fichier n'existe pas ou la saisie n'est pas correcte."
	exit 1
fi

# on change l'extension
choix="${choix/.sql/.sig}"
cheminFichier="$cheminWindows/$choix"

# Vérifation
verificationSignature $cheminFichier

# demontage de répertoire
ecritChaine "Démontage de sauveBDD"
commandeLog "umount -l /media/sauvegarde/"

