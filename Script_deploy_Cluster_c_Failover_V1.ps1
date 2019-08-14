####################################################################################
####          Script para deploy de binarios em ambiente com Cluster            ####
####            Funções:                                                        ####
####            - Checar nó em que a Instancia está ativa.                      ####
####            - Efetuar Deploy no nó Passivo                                  ####
####            - Efetuar Failover                                              ####
####            - Validar Status da Aplicação                                   ####
####            - Efetuar deploy no nó Ativo                                    ####
####            - Validar Status da aplicação                                   ####
####            - Efetuar Failback                                              ####
####                                              V1.0  DAniel Huanca - 08/2019 ####
####################################################################################

#### Importação módulo Power Shell Cluster ####

Import-Module failoverclusters

#### Variaveis Necessárias para o funcionamento do Script  ####

#Param(

$resourcegroup = "NOME_ROLE" #Nome do Serviço - Fornecido pelo TFS
$Files_Source = "CAMINHO ORIGEM" #Origem dos binários - Fornecido pelo TFS
$Files_Destination = "CAMINHO DESTINO" #Destino dos Binários - Fornecido pelo TFS


####  variaveis coletadas pelo script  ####
$resource = Get-ClusterGroup -Name $resourcegroup
$resource.OwnerNode
$resource.State
$resourceOwnerName = $resource.OwnerNode.Name
$ThisNode = hostname
#)

#### Estabalecimento do Nó Passivo ####

$ClusterNodes = Get-ClusterNode
$PoolNodes = $ClusterNodes.Name

 
$OtherNode = Compare-Object -ReferenceObject $ThisNode -DifferenceObject $PoolNodes
$OtherNodeName = $OtherNode.InputObject




if($resourceOwnerName -eq $thisNode)
{ 
    #### Realizar Deploy no Nó Passivo  - Caso não seja o servidor atual ####

    #### Caso seja necessário executar mais de um comando ####
    #Enter-PSSession -ComputerName "COMPUTERNAME"
    #Copy-Item D:\Temp\testeorigem -Destination D:\Temp\testedestino -Recurse
    #Exit-PSSession

    #### Execução de um Único comando ####
    
    Write-Host "Executando o Deploy no servidor $OtherNodeName" -ForegroundColor Green
    Invoke-Command -ComputerName $OtherNodename -ArgumentList $Files_Source,$Files_Destination -ScriptBlock {Copy-Item $args[0] -Destination $args[1] -Recurse}

    #### Failover ####

    Write-Host "Efetuando o Failover do $resource para o nó $otherNodeName" -ForegroundColor Green
    Move-ClusterGroup -Name "$resourcegroup" -Node "$OtherNodeName"

    #### Validação do serviço ####
    $resource = Get-ClusterGroup -Name $resourcegroup
    $resource.OwnerNode
    $resource.State
    $resourceOwnerName = $resource.OwnerNode.Name
    
        If($resource.state -eq "Online")
        {
    
        Write-Host "O Serviço $resource está Online no Nó $resourceOwnerName" -ForegroundColor Green

        #### Deploy no nó secundário ####

        Write-Host "Executando o Deploy no servidor $thisNode"
        Copy-Item $Files_Source -Destination $Files_Destination -Recurse

        #### Failback ####
        
        Write-Host "Efetuando o Failover do $resource para o nó $ThisNode" -ForegroundColor Green
        Move-ClusterGroup -Name "$resourcegroup" -Node "$ThisNode"

        #### Validação do serviço ####
        $resource = Get-ClusterGroup -Name $resourcegroup
        $resource.OwnerNode
        $resource.State
        $resourceOwnerName = $resource.OwnerNode.Name
            
            If($resource.state -eq "Online")
            {
            Write-Host "O Serviço $resource está Online no Nó $resourceOwnerName" -ForegroundColor Green
            Write-Host "O Deploy Foi finalizado e validado nos dois nós do cluster com sucesso." -ForegroundColor Green
            }
            Else
            {
            Write-Host "O serviço não funcionou no nó $resourceOwnerName Favor analisar os logs" -ForegroundColor Red
            }
        }
        Else
        {
        #### saída de erro ao Realizar o primeiro FailOver ####

        Write-Host "O serviço não funcionou no nó $resourceOwnerName Favor analisar os logs" -ForegroundColor Red

        }   

}

else
{ 
    #### Realizar Deploy no Nó Passivo  - Caso  seja o servidor atual ####
    Write-Host "Executando o Deploy no servidor $thisNode"
    Copy-Item $Files_Source -Destination $Files_Destination -Recurse

    #### Failover ####

    Write-Host "Efetuando o Failover do $resource para o nó $thisNode" -ForegroundColor Green
    Move-ClusterGroup -Name "$resourcegroup" -Node "$thisNode" -ForegroundColor Green

    #### Validação do serviço ####
    $resource = Get-ClusterGroup -Name $resourcegroup
    $resource.OwnerNode
    $resource.State
    $resourceOwnerName = $resource.OwnerNode.Name
    
        If($resource.state -eq "Online")
        {
        
        Write-Host "O Serviço $resource está Online no Nó $resourceOwnerName" -ForegroundColor Green

        #### Deploy no nó secundário ####
        Invoke-Command -ComputerName $OtherNodename {$env:VAR=$Files_Source}
        Write-Host "Executando o Deploy no servidor $OtherNodeName" -ForegroundColor Green
        Invoke-Command -ComputerName $OtherNodename -ArgumentList $Files_Source,$Files_Destination -ScriptBlock {Copy-Item $args[0] -Destination $args[1] -Recurse}

        #### Failback ####
        
        Write-Host "Efetuando o Failover do $resource para o nó $otherNodeName" -ForegroundColor Green
        Move-ClusterGroup -Name "$resourcegroup" -Node "$otherNodeName"

        #### Validação do serviço ####
        $resource = Get-ClusterGroup -Name $resourcegroup
        $resource.OwnerNode
        $resource.State
        $resourceOwnerName = $resource.OwnerNode.Name

         If($resource.state -eq "Online")
            {
            Write-Host "O Serviço $resource está Online no Nó $resourceOwnerName" -ForegroundColor Green
            White-Host "O Deploy Foi finalizado e validado nos dois nós do cluster com sucesso." -ForegroundColor Green
            }
            Else
            {
            Write-Host "O serviço não funcionou no nó $resourceOwnerName Favor analisar os logs" -ForegroundColor Red
            }
        }
        Else
        {

        }

} 
