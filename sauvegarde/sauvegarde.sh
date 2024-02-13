#!/bin/bash

# script écrit par RUFFENACH Timothée
# Le 13/02/2024

# Variables pour les chemins et fichier
journalisationChemin=/var/log/sauvegarde/
journalisationFichier=/var/log/sauvegarde/sauvegarde.log
partageWindows=/sauveBDD
cheminWindows=/media/sauvegarde

#Variables commande
erreur=""

# Vérifie si le chemin var/log/sauvegarde/existe
if [ ! -d "$journalisationChemin" ]; then
	# création s'il n'existe pas
	mkdir -p "$journalisationChemin"
fi

# fonction journalisation des erreurs
logErreur() {
	if [ -n "$erreur" ]; then
		echo $horoDatage $erreur >> $journalisationFichier
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
	erreur=$(eval $1 2>&1 >/dev/null)
	logErreur
}

# montage du répertoire
ecritChaine "Montage de sauveBDD"
commandeLog "mount -t cifs //0.0.0.0$partageWindows /media/sauvegarde/ -o username=sauvegardebdd,password=mdp,rw"

# dump de la base de donnée
ecritChaine "Dump de la BDD de GLPI"
commandeLog "mysqldump glpi > $cheminWindows/glpi.sql"
ecritChaine "Dump de la BDD de GRR"
commandeLog "mysqldump grrdb > $cheminWindows/grr.sql"

# signature des fichiers
ecritChaine "Signature glpli"
commandeLog "sha256sum $cheminWindows/glpi.sql > $cheminWindows/glpi.sig"
ecritChaine "Signature grr"
commandeLog "sha256sum $cheminWindows/grr.sql > $cheminWindows/grr.sig"

# compression et archivage
ecritChaine "Archivage glpi"
commandeLog "tar -czf $cheminWindows/glpi.tar.gz $cheminWindows/glpi.sql -P $cheminWindows/glpi.sql -P $cheminWindows/glpi.sig"
ecritChaine "Archivage grr"
commandeLog "tar -czf $cheminWindows/grr.tar.gz $cheminWindows/grr.sql -P $cheminWindows/grr.sql -P $cheminWindows/grr.sig"

# récupération de la date
date=$(date +'%d-%m-%Y')

# chiffrement
ecritChaine "Chiffrement de glpi.tar.gz"
commandeLog "echo 'mdp' | gpg --batch --yes --passphrase-fd 0 --symmetric --output $cheminWindows/glpi$date.crypt $cheminWindows/glpi.tar.gz"
ecritChaine "Chiffrement de grr.tar.gz"
commandeLog "echo 'mdp' | gpg --batch --yes --passphrase-fd 0 --symmetric --output $cheminWindows/grr$date.crypt $cheminWindows/grr.tar.gz"

#effacement les fichiers non chiffrés
ecritChaine "effacement des fichiers non chiffrés" 
commandeLog "rm $cheminWindows/*.sql"
ecritChaine "effacement signature" 
commandeLog "rm $cheminWindows/*.sig"
ecritChaine "effacement des archives" 
commandeLog "rm $cheminWindows/*.tar.gz"

# signature fichier chiffrés
ecritChaine "signature fichiers chiffrés" 
ecritChaine "Signature fichier glpi$date.crypt" 
commandeLog "sha256sum $cheminWindows/glpi$date.crypt > $cheminWindows/glpi$date.sig"
ecritChaine "Signature fichies grr$date.crypt" 
commandeLog "sha256sum $cheminWindows/grr$date.crypt > $cheminWindows/grr$date.sig"

# démontage 
ecritChaine "démontage de sauvegarde" 
commandeLog "umount -l /media/sauvegarde/"
