#!/bin/bash

##################################################################################################################################################
#																	versie: 5																	 #
#																Configuratie-parameter															 #
#																																				 #
##################################################################################################################################################

set -m                          						# Enable Job Control
export LC_ALL="nl_NL.UTF-8"     						# .tjes en ,tjes

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )	#locatie van het script bepalen
EXPORT=$DIR"/ipscan.csv"
LOG=$DIR"/ipscan.log"
IP="FOUT"
SNMPGET="/usr/bin/snmpget"
NMAP="/usr/bin/nmap"

IOD1="1.3.6.1.2.1.1.5.0"                    			#Hostname
IOD2="1.3.6.1.2.1.47.1.1.1.1.13.1001"       			#Modelnumer on Cisco
IOD3="1.3.6.1.2.1.1.1.0"                    			#Modelnumer on HP

MAXPROC=50

##################
#### ip-reeks ####
##################

#Reeks 1;  eerste octet minimum en maximum
EEN1MIN=10
EEN1MAX=10

#Reeks 1;  tweede octet minimum en maximum
TWEE1MIN=1
TWEE1MAX=254

#Reeks 1;  derde octet minimum en maximum
DRIE1MIN=3
DRIE1MAX=4

#Reeks 1;  vierde octet minimum en maximum
VIER1MIN=1
VIER1MAX=254

#Reeks 2;  eerste octet minimum en maximum
EEN2MIN=10
EEN2MAX=10

#Reeks 2;  tweede octet minimum en maximum
TWEE2MIN=10
TWEE2MAX=10

#Reeks 2;  derde octet minimum en maximum
DRIE2MIN=1
DRIE2MAX=70

#Reeks 2;  vierde octet minimum en maximum
VIER2MIN=1
VIER2MAX=254

##################################################################################################################################################
#																																				 #
#																	Begin script																 #
#																																				 #
##################################################################################################################################################


################
#### checks ####
################

if [ "$(id -u)" != "0" ]; then
    echo "Sorry, you are not root."
    exit 1
fi

if [ ! -e $NMAP ]; then
    echo "nmap niet gevonden, installeer nmap of verbeter het pad in de configuratie"
    exit
fi

if [ ! -e $SNMPGET ]; then
    echo "snmpget niet gevonden, installeer snmpget of verbeter het pad in de configuratie"
    exit
fi


#### Bestanden voorbereiden ####

echo "start: $(date)" > $LOG
echo "" > $EXPORT

#### Tijden initieren ####

elapsed=$(date +%s.%N)
res1=$(date +%s.%N)

################
####Functies####
################

DISCOVER(){
ALIVE=$(sudo nmap -sn -PS53,80,443 -PU -PY $1 | grep "1 host up"  | wc -l )
if [ $ALIVE -eq 1 ] ; then
    printf "%s%s%s\n" \
    "$1 ," \
    "$(snmpget -c private -v 2c -t 1 -r 1 $1 $IOD1 $IOD2 $IOD3 | grep -o '\".*\"' | awk '/\".*\"/ {print $0,",";next}' | sed ':a;N;$!ba;s/\n/ /g' )" \
    "$(sudo nmap -T5 -O $1 | grep -o "^.*Running:.*$" | sed 's/,/\./')" >> $EXPORT
fi
}

TIMELOG(){
    # Let niet op de . naar , en , naar . conversies, bc en printf gebruiken verschillende tekens.
    printf "%s %.3f %s %.3f %s\n" \
    "Netwerk $1 in : " \
    "$(echo " $3 - $2 " |  sed 's/,/\./' | bc -l  | sed 's/\./,/')" \
    " seconden, totale tijd : " \
    "$(echo "( $3 - $4 ) / 60,0"|  sed 's/,/\./' | bc -l  | sed 's/\./,/')" \
    " minuten (decimale waarde)" >> $LOG
}

################
#### Logic  ####
################

#nested loop voor alle IP-addressen (octet een, twee, drie en vier)
# Reeks 1
for (( EEN1=$EEN1MIN; EEN1<=$EEN1MAX; EEN1++ )) ; do
    for (( TWEE1=$TWEE1MIN; TWEE1<=$TWEE1MAX; TWEE1++ )) ; do
        for (( DRIE1=$DRIE1MIN; DRIE1<=$DRIE1MAX; DRIE1++ )); do
            for (( VIER1=$VIER1MIN; VIER1<=$VIER1MAX; VIER1++ )); do
        	    IP="$EEN1.$TWEE1.$DRIE1.$VIER1"
                DISCOVER $IP &
                NPROC=$(($NPROC+1))
                if [ "$NPROC" -ge $MAXPROC ]; then
                    wait
                    NPROC=0
                fi
            done  	

            #doorlooptijd loggen
	        res2=$(date +%s.%N)
	        TIMELOG "$EEN1.$TWEE1.$DRIE1.0/24" $res1 $res2 $elapsed
            res1=$(date +%s.%N) #tijd resetten voor tussentijden
        done
    done
done

# Reeks 2
for (( EEN2=$EEN2MIN; EEN2<=$EEN2MAX; EEN2++ )); do
    for (( TWEE2=$TWEE2MIN; TWEE2<=$TWEE2MAX; TWEE2++ )); do
        for (( DRIE2=$DRIE2MIN; DRIE2<=$DRIE2MAX; DRIE2++ )); do
            for (( VIER2=$VIER2MIN; VIER2<=$VIER2MAX; VIER2++ )); do
                IP="$EEN2.$TWEE2.$DRIE2.$VIER2"
                DISCOVER $IP &
                NPROC=$(($NPROC+1))
                if [ "$NPROC" -ge $MAXPROC ]; then
                    wait
                    NPROC=0
                fi
            done 

            #doorlooptijd loggen
            res2=$(date +%s.%N)
            TIMELOG "$EEN2.$TWEE2.$DRIE2.0/24" $res1 $res2 $elapsed
            res1=$(date +%s.%N) #tijd resetten voor tussentijden
        done
    done
done
###################
### Opschonen #####
###################

#Dubbele entries verwijderen
echo "Dubbele entries verwijderen..." >> $LOG
sort -u $EXPORT

#Comma's aan het einde van de regel verwijderen
echo "Comma's aan het einde van de regel verwijderen..." >> $LOG
perl -pi -e 's/,\n/\n/g' $EXPORT 

#Bestand CSV-compliant maken (tabelen recht trekken) (fase 1, host is up, geen gegevens)
echo "Lege resultaten weggooien..." >> $LOG
echo "Bestand CSV-compliant maken (tabelen recht trekken) (fase 1, host is up, geen gegevens)..." >> $LOG
O=$(grep -o '[0-9]\{2\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\ ,\n' $EXPORT)
while read -r line
do
    T=$(echo "$line" | sed 's/,\n/,niet gevonden,niet gevonden,niet gevonden\n/')
    sed -i "s/$line/$T/" $EXPORT
done <<< "$O"

#Bestand CSV-compliant maken (tabelen recht trekken) (fase 2, host is up, geen Cisco of HP switch)
echo "Bestand CSV-compliant maken (tabelen recht trekken) (fase 2, host is up, geen Cisco of HP switch)..." >> $LOG
O=$(grep -o '[0-9]\{2\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\ ,Running' $EXPORT)
while read -r line
do
    T=$(echo "$line" | sed 's/,Running/,niet gevonden,niet gevonden,Running/')
    sed -i "s/$line/$T/" $EXPORT
done <<< "$O"

#Log sluiten
echo "Stop: $(date)" >> $LOG

##################################################################################################################################################
#																																				 #
#																	Einde script																 #
#																																				 #
##################################################################################################################################################