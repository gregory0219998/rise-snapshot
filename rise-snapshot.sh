#!/bin/bash
VERSION="0.1"

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

#============================================================
#= snapshot.sh v0.2 created by mrgr                         =
#= Please consider voting for delegate mrgr      
#= Modified by gregorst
#============================================================
echo " "

if [ ! -f ../rise-node/app.js ]; then
  echo "Error: No rise installation detected. Exiting."
  exit 1
fi

if [ "\$USER" == "root" ]; then
  echo "Error: rise should not be run be as root. Exiting."
  exit 1
fi

rise_CONFIG=~/rise-node/config.json
DB_NAME="$(grep "database" $rise_CONFIG | cut -f 4 -d '"')"
DB_USER="$(grep "user" $rise_CONFIG | cut -f 4 -d '"')"
DB_PASS="$(grep "password" $rise_CONFIG | cut -f 4 -d '"' | head -1)"
SNAPSHOT_COUNTER=snapshot/counter.json
SNAPSHOT_LOG=snapshot/snapshot.log
if [ ! -f "snapshot/counter.json" ]; then
  mkdir -p snapshot
  sudo chmod a+x rise-snapshot.sh
  echo "0" > $SNAPSHOT_COUNTER
  sudo chown postgres:${USER:=$(/usr/bin/id -run)} snapshot
  sudo chmod -R 777 snapshot
fi
SNAPSHOT_DIRECTORY=snapshot/


NOW=$(date +"%d-%m-%Y - %T")
################################################################################

create_snapshot() {
  export PGPASSWORD=$DB_PASS
  echo " + Creating snapshot"
  echo "--------------------------------------------------"
  echo "..."
  sudo rm  $SNAPSHOT_DIRECTORY'blockchain.db.gz'
   echo "..."
  sudo su postgres -c "pg_dump -Fp $DB_NAME > $SNAPSHOT_DIRECTORY'blockchain.db'"
  blockHeight=`psql -d $DB_NAME -U $DB_USER -h localhost -p 5432 -t -c "select height from blocks order by height desc limit 1;"`
  dbSize=`psql -d $DB_NAME -U $DB_USER -h localhost -p 5432 -t -c "select pg_size_pretty(pg_database_size('$DB_NAME'));"`
  sudo gzip snapshot/blockchain.db

  if [ $? != 0 ]; then
    echo "X Failed to create snapshot." | tee -a $SNAPSHOT_LOG
    exit 1
  else
    echo "$NOW -- OK snapshot created successfully at block$blockHeight ($dbSize)." | tee -a $SNAPSHOT_LOG
  fi

}

restore_snapshot(){
  echo " + Restoring snapshot"
  echo "--------------------------------------------------"
  SNAPSHOT_FILE=`ls -t snapshot/blockchain.db.gz | head  -1`
  if [ -z "$SNAPSHOT_FILE" ]; then
    echo "****** No snapshot to restore, please consider create it first"
    echo " "
    exit 1
  fi
  echo "Snapshot to restore = $SNAPSHOT_FILE"

  read -p "Please stop node app.js first, are you ready (y/n)? " -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
     echo "***** Please stop node.js first.. then execute restore again"
     echo " "
     exit 1
  fi

#snapshot restoring..
  export PGPASSWORD=$DB_PASS
  pg_restore -d $DB_NAME "$SNAPSHOT_FILE" -U $DB_USER -h localhost -c -n public

  if [ $? != 0 ]; then
    echo "X Failed to restore."
    exit 1
  else
    echo "OK snapshot restored successfully."
  fi

}

show_log(){
  echo " + Snapshot Log"
  echo "--------------------------------------------------"
  cat snapshot/snapshot.log
  echo "--------------------------------------------------END"
}

################################################################################

case $1 in
"create")
  create_snapshot
  ;;
"restore")
  restore_snapshot
  ;;
"log")
  show_log
  ;;
"hello")
  echo "Hello my friend - $NOW"
  ;;
"help")
  echo "Available commands are: "
  echo "  create   - Create new snapshot"
  echo "  restore  - Restore the last snapshot available in folder snapshot/"
  echo "  log      - Display log"
  ;;
*)
  echo "Error: Unrecognized command."
  echo ""
  echo "Available commands are: create, restore, log, help"
  echo "Try: bash rise-snapshot.sh help"
  ;;
esac
