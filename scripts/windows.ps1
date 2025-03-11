# Enable error handling
$ErrorActionPreference = "Stop"

# Simple function to log messages to console and EC2 console log
function Write-Log {
    param($Message)
    
    # Get timestamp for better logging
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "[$timestamp] $Message"
    
    # Write to PowerShell console
    Write-Host $formattedMessage
    
    # Write to EC2 Console Log (via COM1 serial port) - this appears in AWS Console's "Get System Log"
    try {
        $formattedMessage | Out-File -FilePath '\\.\COM1' -Append -ErrorAction SilentlyContinue
    }
    catch {
        # If COM1 is not available (e.g., when testing locally), just continue
        Write-Host "Note: Unable to write to COM1 port"
    }
}

# Function to handle errors consistently
function Handle-Error {
    param(
        [string]$FunctionName,
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    Write-Log "ERROR in $FunctionName : $($ErrorRecord.Exception.Message)"
    Write-Log "Stack trace: $($ErrorRecord.ScriptStackTrace)"
    exit 1
}

try {
    Write-Log "Starting Windows configuration..."

    # Configure Windows Firewall
    Write-Log "Configuring Windows Firewall..."
    try {
        New-NetFirewallRule -DisplayName "HTTP Inbound" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow
        New-NetFirewallRule -DisplayName "HTTPS Inbound" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
        Write-Log "Firewall rules configured successfully"
    }
    catch {
        Handle-Error -FunctionName "Configure-Firewall" -ErrorRecord $_
    }

    Write-Log "All configurations completed successfully"
}
catch {
    Handle-Error -FunctionName "Main" -ErrorRecord $_
}