#!powershell

#Requires -Module Ansible.ModuleUtils.Legacy
#Requires -Module Ansible.ModuleUtils.CommandUtil
#AnsibleRequires -OSVersion 6.2
#AnsibleRequires -CSharpUtil Ansible.Basic


# Initializing ansible module parameters
$spec = @{
    options = @{
        hostname  =  @{ type = "str"; required = $true }
        user      =  @{ type = "str"; required = $true }
        passwd    =  @{ type = "str"; required = $true }
        file_path =  @{ type = "str"; required = $true }
        dest      =  @{ type = "str"; required = $true }
        secure    =  @{ type = "bool" }
        hostkey   =  @{ type = "str" }
    }
}


#region PowerShell Function
function DownloadFileSftp {
    param (
        [Parameter(Mandatory = $true)][String]$hostname,
        [Parameter(Mandatory = $true)][String]$user,
        [Parameter(Mandatory = $true)][String]$passwd,
        [Parameter(Mandatory = $true)][String]$file_path,
        [Parameter(Mandatory = $true)][String]$dest,
        [Parameter(Mandatory = $true)][Boolean]$secure,
        [Parameter()][String]$hostkey
    )

    # TODO: add checking and downloading winscp.dll from url and maybe disposing stuff at the end
    # or even better if it's possible write into a byteslike object

    # Load WinSCP .NET assembly
    $WinSCPdllPATH = "C:\"
    Add-Type -Path $(Join-Path $WinSCPdllPATH "WinSCPnet.dll")
    
    # Set up session options
    # If secure, give up security - else you have to provide hostkey
    if (-Not $secure) {
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol              = [WinSCP.Protocol]::Sftp
        HostName              = "${hostname}"
        UserName              = "${user}"
        Password              = "${passwd}"
        SshHostKeyPolicy      = "GiveUpSecurityAndAcceptAny"
        }
    } else {
        $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
            Protocol              = [WinSCP.Protocol]::Sftp
            HostName              = "${hostname}"
            UserName              = "${user}"
            Password              = "${passwd}"
            SshHostKeyFingerprint = "${hostkey}"
        }
    }

    # Creating session object with previously given parameters
    $session = New-Object WinSCP.Session

    try
    {
    
        # Connect
        $session.Open($sessionOptions)
        # Download
        $session.GetFiles($file_path, $dest)
    
    }

    # Catching connession errors and failing task
    catch {
        # Getting error message
        $_error = $Error[0].Exception.InnerException.Message

        # Creating a fail object
        $returning  = New-Object psobject @{
            changed = $false
            msg     = $_Error
        }

        # Failing
        Fail-json $returning

    }

    finally
    {
        # Exit
        $session.Dispose()
    }
    
}
#endregion

#Region Ansible module utils
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec) #Creating a module
$hostname  = $module.Params.hostname       #Defining function parameters as parameters coming from our module
$user      = $module.Params.user           #Defining function parameters as parameters coming from our module
$passwd    = $module.Params.passwd         #Defining function parameters as parameters coming from our module
$file_path = $module.Params.file_path      #Defining function parameters as parameters coming from our module
$dest      = $module.Params.dest           #Defining function parameters as parameters coming from our module
$secure    = $module.Params.secure         #Defining function parameters as parameters coming from our module
$hostkey   = $module.Params.hostkey        #Defining function parameters as parameters coming from our module
#Endregion


# Failing if secure=true but no hostkey is passed to the module
if (-Not $secure) {
    if ($hostkey -eq "") {
        $returning = New-Object psobject @{
            changed       = $false
            failed        = $true
            msg           = "Host key not provided in secure mode"
        }

        Exit-Json $returning
    }
}

# Choosing wich command to run based on passed parameters
switch ($secure) {
    $false { $result = DownloadFileSftp -hostname $hostname -user $user -passwd $passwd -file_path $file_path -dest $dest  -secure $secure }
    $true  { $result = DownloadFileSftp -hostname $hostname -user $user -passwd $passwd -file_path $file_path -dest $dest  -secure $secure -hostkey $hostkey}
}

# Catching internal transmission errors even if connections goes ok
# This could be wrong path on local machine, permission errors etc.
if ($result.isSuccess -eq "true") {

    $returning = New-Object psobject @{
        changed     = $true
        msg         = "File successfully transfered"
        remote_src  = $result.Transfers.Filename
        destination = $result.Transfers.Destination
        secure_mode = $secure
    }

    #Exiting
    Exit-Json $returning

} else {                                                        # Everything went fine
    
    $returning = New-Object psobject @{
        changed       = $false
        failed        = $true
        error_message = $result.Failures.Message
        output        = $result.Transfers.Error.Session.Output
    }

    #Exiting
    Exit-Json $returning

}
