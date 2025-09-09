# - EventID 21: Bir RDP oturumunun kesildiğini veya oturumun kapandığını gösterir.
# - EventID 25: Bir RDP oturumunun yeniden bağlandığını veya bağlantının kurulduğunu gösterir.
# - EventID 4624: Başarılı bir oturum açma girişimini gösterir.
# - LogonType 10: RDP (Remote Desktop) ile yapılan etkileşimli oturum açma türünü gösterir.

# Event ID 4624 (LogonType 10), 21 ve 25
$tsEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
    Id      = 21, 25
} -MaxEvents 1000

$securityEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id      = 4624
} -MaxEvents 1000 | Where-Object {
    $xml = [xml]$_.ToXml()
    $logonType = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' } | Select-Object -ExpandProperty '#text'
    $logonType -eq '10'
}

$tsResult = foreach ($event in $tsEvents) {
    $xml = [xml]$event.ToXml()
    $address = $xml.Event.UserData.EventXML.Address

    if ($address) {
        [PSCustomObject]@{
            IPAddress = $address
            EventType = $event.Id  
        }
    }
}

$securityResult = foreach ($event in $securityEvents) {
    $xml = [xml]$event.ToXml()
    $address = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' } | Select-Object -ExpandProperty '#text'

    if ($address -and $address -ne '127.0.0.1' -and $address -ne '-') {
        [PSCustomObject]@{
            IPAddress = $address
            EventType = $event.Id
        }
    }
}

$allResults = $tsResult + $securityResult

$ipCounts = @{}

foreach ($result in $allResults) {
    $ip = $result.IPAddress
    $eventType = $result.EventType
    
    if (-not $ipCounts.ContainsKey($ip)) {
        $ipCounts[$ip] = [PSCustomObject]@{
            IPAddress = $ip
            EventID_21_Count = 0
            EventID_25_Count = 0
            EventID_4624_Count = 0
        }
    }

    if ($eventType -eq 21) {
        $ipCounts[$ip].EventID_21_Count++
    } elseif ($eventType -eq 25) {
        $ipCounts[$ip].EventID_25_Count++
    } elseif ($eventType -eq 4624) {
        $ipCounts[$ip].EventID_4624_Count++
    }
}


$finalResult = $ipCounts.Values | Sort-Object { $_.EventID_21_Count + $_.EventID_25_Count + $_.EventID_4624_Count } -Descending

$finalResult | Format-Table -AutoSize
