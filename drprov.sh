#!/bin/bash
echo "get servers for CG"
didata tag list --tagKeyName=CG --tagKeyValue=$1 --query "ReturnKeys:Asset ID" | awk '{print $3}'  | sed '/^$/d' > working/cg-assets
echo "get server info"
x=0
echo "Source_MCP,Source_VM_Name,Source_VM_IPV4,Source_VM_IPV6,Source_VM_OS,Source_VM_Displayname,Target_MCP,Target_VM_Name,Target_VM_IPV4,Target_VM_IPV6,Target_VM_OS,Target_VM_Displayname" > dr-server-mapping.csv

while read p; do
  x=$((x+1))
  value=$( didata server info --serverId=$p --query="ReturnKeys:datacenterId" | awk '{print $2}' )
  if [ $value == $2 ]
    then
        #get prod server info
        #echo "PROD server" >> dr-server-mapping.csv
        sserver=$( didata --outputType=json server info --serverId=$p --query="ReturnKeys:ID,Name,Private IPv4 0,ipv6,OS_displayName,datacenterId" )
	echo -n $value, >> dr-server-mapping.csv
         echo -n $sserver | jq .[0].ID | sed -e 's/^"//'  -e 's/"$//' |tr '\n' ',' >> dr-server-mapping.csv 
	echo -n $sserver | jq '.[0]["Private IPv4 0"]' | sed -e 's/^"//'  -e 's/"$//' |tr '\n' ',' >> dr-server-mapping.csv
        echo -n $sserver | jq .[0].ipv6 | sed -e 's/^"//'  -e 's/"$//' |tr '\n' ',' >> dr-server-mapping.csv
	 echo -n $sserver | jq .[0].OS_displayName | sed -e 's/^"//'  -e 's/"$//' |tr '\n' ',' >> dr-server-mapping.csv
	 echo -n $sserver | jq .[0].Name | sed -e 's/^"//'  -e 's/"$//' |tr '\n' ',' >> dr-server-mapping.csv

	#get targer server info
        dr_target=$( didata tag list --assetId $p --tagKeyName target --query "ReturnKeys:Value" | awk '{print $2}' )        
	dest=$( didata --outputType=json server info --serverId=$dr_target --query="ReturnKeys:ID,Name,Private IPv4 0,ipv6,OS_displayName,datacenterId" )
	echo -n $dest | jq .[0].datacenterId | sed -e 's/^"//'  -e 's/"$//' |tr '\n' ',' >> dr-server-mapping.csv
        echo -n $dest | jq .[0].ID | sed -e 's/^"//'  -e 's/"$//'  |tr '\n' ',' >> dr-server-mapping.csv
	 echo -n $dest | jq '.[0]["Private IPv4 0"]' | sed -e 's/^"//'  -e 's/"$//'|tr '\n' ','  >> dr-server-mapping.csv
	 echo -n $dest | jq .[0].ipv6 | sed -e 's/^"//'  -e 's/"$//' |tr '\n' ','>> dr-server-mapping.csv
	 echo -n $dest | jq .[0].OS_displayName | sed -e 's/^"//'  -e 's/"$//'|tr '\n' ','  >> dr-server-mapping.csv
	 echo -n $dest | jq .[0].Name | sed -e 's/^"//'  -e 's/"$//' >> dr-server-mapping.csv

  fi
done < working/cg-assets
echo "procesed $x servers"
echo "done"

