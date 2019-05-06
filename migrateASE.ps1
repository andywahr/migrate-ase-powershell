$srcRGName = 'rg-whattest'
$targetRGName = 'rg-whattest'
$sourceASE = 'andywahrwhat-v1'
$targetASE = 'andywahrwhat-v2'

Get-AzAppServicePlan -ResourceGroupName $srcRGName |? { $_.Name -match 'ping-v1$' } |% {
    $size = "Small"
    $newPlanName = $_.Name
    $sameResourceGroup =  [string]::Equals($srcRGName, $targetRGName, [System.StringComparison]::OrdinalIgnoreCase);
    $location = $_.Location

    $apps = Get-AzWebApp -AppServicePlan $_

    if ( $sameResourceGroup )
    {
        $newPlanName += "-v2"
        "Cloning AppServicePlan $($_.Name) to same resource group, ensuring unique name $newPlanName"
    }

    $destAppServicePlan = Get-AzAppServicePlan -ResourceGroupName $targetRGName -name $newPlanName
    if ( $destAppServicePlan )
    {
        "AppServicePlan $newPlanName already exists"
    }
    else
    {
        if ( $_.Sku.Size -eq 'I2' ) 
        {
            $size = "Medium"
        }

        if ( $_.Sku.Size -eq 'I3' )
        {
            $size = "Large"
        }
        "Cloning AppServicePlan $($_.Name) to $newPlanName"
        $destAppServicePlan = New-AzAppServicePlan -name $newPlanName -AseName $targetASE -AseResourceGroupName $targetRGName -Location $location -ResourceGroupName $targetRGName -Tier $_.Sku.Tier -WorkerSize  $size -NumberOfWorkers $_.Sku.Capacity
    }

    while ( $destAppServicePlan.Status -ne 'Ready' ) 
    {
        "New AppService Plan $($destAppServicePlan.Name) is not Ready, currently $($destAppServicePlan.Status), waiting 5 minutes";
        sleep -Seconds 300
        $destAppServicePlan = Get-AzAppServicePlan -ResourceGroupName $targetRGName -name $newPlanName
    }

    $apps |% { 
        $srcapp = $_
        $srcapp.Enabled = $false
        $newAppName = $srcapp.Name
        
        if ( $sameResourceGroup )
        {
            $newAppName += "-v2"
            "Cloning AppService $($srcapp.Name) to same resource group, ensuring unique name $newAppName"
        }
        "Cloning AppService $($srcapp.Name) to $newAppName"
        $destapp = New-AzWebApp -ResourceGroupName $targetRGName -Name $newAppName -Location $location -AppServicePlan $newPlanName -ASEName $targetASE -ASEResourceGroupName $targetRGName -SourceWebApp $srcapp
        Stop-AzWebApp -ResourceGroupName $targetRGName -Name $newAppName
    }    
}

