cluster_name=mycluster
bx login --apikey bmdCQ6k1O7h2Ue5fc9Cyf3Sti2rJbBvIQCWEFX7BlOK5 -a api.ng.bluemix.net
bx cs init

bx cs workers $cluster_name
bx cs cluster-config $cluster_name
