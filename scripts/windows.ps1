# Enable error handling
$ErrorActionPreference = "Stop"

# Simple function to log messages
function Write-Log {
    param($Message)
    Write-Host $Message
}

try {
    Write-Log "Starting Windows configuration..."

    # Set administrator password
    Write-Log "Setting administrator password..."
    try {
        $admin = [adsi]("WinNT://./administrator, user")
        $admin.psbase.invoke("SetPassword", "${admin_password}")
        Write-Log "Administrator password set successfully"
    }
    catch {
        Write-Log "Failed to set administrator password: $_"
        exit 1
    }

    # Configure Windows Firewall
    Write-Log "Configuring Windows Firewall..."
    try {
        New-NetFirewallRule -DisplayName "HTTP Inbound" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow
        New-NetFirewallRule -DisplayName "HTTPS Inbound" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
        Write-Log "Firewall rules configured successfully"
    }
    catch {
        Write-Log "Failed to configure firewall rules: $_"
        exit 1
    }

    # Verify configurations
    Write-Log "Verifying configurations..."
    
    # Test administrator password
    Write-Log "Verifying administrator account..."
    try {
        $adminUser = Get-LocalUser -Name "administrator" -ErrorAction Stop
        if (-not $adminUser) {
            Write-Log "Administrator account verification failed"
            exit 1
        }
    } catch {
        Write-Log "Failed to verify administrator account: $_"
        exit 1
    }
    
    # Verify firewall rules
    Write-Log "Verifying firewall rules..."
    try {
        $httpRule = Get-NetFirewallRule -DisplayName "HTTP Inbound" -ErrorAction Stop
        $httpsRule = Get-NetFirewallRule -DisplayName "HTTPS Inbound" -ErrorAction Stop

        if (-not $httpRule -or -not $httpsRule) {
            Write-Log "Firewall rules verification failed"
            exit 1
        }
        Write-Log "Firewall rules verified successfully"
    } catch {
        Write-Log "Failed to verify firewall rules: $_"
        exit 1
    }

    # Test network connectivity
    Write-Log "Testing network connectivity..."
    try {
        $testConnection = Test-NetConnection -ComputerName "8.8.8.8" -Port 443 -WarningAction SilentlyContinue
        if (-not $testConnection.TcpTestSucceeded) {
            Write-Log "Network connectivity test failed"
            exit 1
        }
        Write-Log "Network connectivity verified successfully"
    } catch {
        Write-Log "Failed to test network connectivity: $_"
        exit 1
    }

    # ======================================================
    # SSM Agent Installation and Configuration
    # ======================================================
    Write-Log "Checking AWS SSM Agent status..."
    
    # Check if SSM Agent is already installed
    $SSMService = Get-Service -Name "AmazonSSMAgent" -ErrorAction SilentlyContinue
    
    if ($null -eq $SSMService) {
        Write-Log "SSM Agent not found - installing..."
        try {
            # Download the SSM Agent installer
            Write-Log "Downloading SSM Agent installer..."
            $tempDir = "C:\Temp"
            if (!(Test-Path -Path $tempDir)) {
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            }
            
            $ssmInstallerUrl = "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/windows_amd64/AmazonSSMAgentSetup.exe"
            $installerPath = "$tempDir\AmazonSSMAgentSetup.exe"
            
            Invoke-WebRequest -Uri $ssmInstallerUrl -OutFile $installerPath -UseBasicParsing
            
            # Install the SSM Agent
            Write-Log "Installing SSM Agent..."
            Start-Process -FilePath $installerPath -ArgumentList "/install", "/quiet" -Wait
            
            # Check if installation was successful
            $SSMService = Get-Service -Name "AmazonSSMAgent" -ErrorAction Stop
            Write-Log "SSM Agent installed successfully"
        }
        catch {
            Write-Log "Failed to install SSM Agent: $_"
            exit 1
        }
    }
    else {
        Write-Log "SSM Agent is already installed"
    }
    
    # Configure SSM Agent if needed
    Write-Log "Configuring SSM Agent..."
    try {
        # Create SSM Agent configuration directory if it doesn't exist
        $ssmConfigDir = "$env:ProgramData\Amazon\SSM"
        if (!(Test-Path -Path $ssmConfigDir)) {
            New-Item -ItemType Directory -Path $ssmConfigDir -Force | Out-Null
        }
        
        # Restart SSM Agent to ensure it's running with the latest configuration
        Restart-Service -Name "AmazonSSMAgent" -Force
        Start-Sleep -Seconds 5
        
        # Verify SSM Agent is running
        $SSMService = Get-Service -Name "AmazonSSMAgent" -ErrorAction Stop
        
        if ($SSMService.Status -ne "Running") {
            Write-Log "SSM Agent is not running. Attempting to start..."
            Start-Service -Name "AmazonSSMAgent"
            Start-Sleep -Seconds 5
            $SSMService = Get-Service -Name "AmazonSSMAgent" -ErrorAction Stop
        }
        
        if ($SSMService.Status -ne "Running") {
            Write-Log "Failed to start SSM Agent service"
            exit 1
        }
        
        Write-Log "SSM Agent is running properly"
        
        # Verify SSM Agent connectivity to AWS SSM service
        Write-Log "Verifying SSM Agent connectivity..."
        
        # Check SSM Agent log for successful registration
        $ssmLogPath = "C:\ProgramData\Amazon\SSM\Logs\amazon-ssm-agent.log"
        
        if (Test-Path -Path $ssmLogPath) {
            $logContent = Get-Content -Path $ssmLogPath -Tail 100
            
            # Check for successful registration message in logs
            $registered = $logContent | Select-String -Pattern "Successfully registered the instance" -Quiet
            
            if ($registered) {
                Write-Log "SSM Agent successfully registered with AWS SSM service"
            }
            else {
                Write-Log "Warning: Could not confirm SSM Agent registration in logs. This might be normal for a new instance."
            }
        }
        else {
            Write-Log "Warning: SSM Agent log file not found. Cannot verify registration status."
        }
    }
    catch {
        Write-Log "Error configuring or verifying SSM Agent: $_"
        exit 1
    }

    Write-Log "All configurations completed successfully"
}
catch {
    Write-Log "Unexpected error: $_"
    exit 1
}