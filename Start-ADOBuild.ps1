﻿function Start-ADOBuild
{
    <#
    .Synopsis
        Starts an Azure DevOps Build
    .Description
        Starts a build in Azure DevOps, using an existing BuildID,
        
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
    # The Organization
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [Alias('Org')]
    [string]
    $Organization,

    # The Project
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [string]
    $Project,

    # The server.  By default https://dev.azure.com/.
    [Parameter(ValueFromPipelineByPropertyName)]
    [uri]
    $Server = "https://dev.azure.com/",

    # The api version.  By default, 5.1.
    [string]
    $ApiVersion = "5.1",

    # The Build ID
    [Parameter(Mandatory,ParameterSetName='BuildID',ValueFromPipelineByPropertyName)]
    [string]
    $BuildID,

    # The Build Definition ID
    [Parameter(Mandatory,ParameterSetName='DefinitionId',ValueFromPipelineByPropertyName)]
    [string]
    $DefinitionID,

    # The Build Definition Name
    [Parameter(Mandatory,ParameterSetName='DefinitionName',ValueFromPipelineByPropertyName)]
    [string]
    $DefinitionName,

    # The source branch (the branch used for the build).
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]
    $SourceBranch,

    # The source version (the commit used for the build).
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]
    $SourceVersion,

    # The build parameters
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('Parameters')]
    [string]
    $Parameter,

    # A Personal Access Token
    [Alias('PAT')]
    [string]
    $PersonalAccessToken,

    # Specifies a user account that has permission to send the request. The default is the current user.
    # Type a user name, such as User01 or Domain01\User01, or enter a PSCredential object, such as one generated by the Get-Credential cmdlet.
    [pscredential]
    [Management.Automation.CredentialAttribute()]
    $Credential,

    # Indicates that the cmdlet uses the credentials of the current user to send the web request.
    [Alias('UseDefaultCredential')]
    [switch]
    $UseDefaultCredentials,

    # Specifies that the cmdlet uses a proxy server for the request, rather than connecting directly to the Internet resource. Enter the URI of a network proxy server.
    [uri]
    $Proxy,

    # Specifies a user account that has permission to use the proxy server that is specified by the Proxy parameter. The default is the current user.
    # Type a user name, such as "User01" or "Domain01\User01", or enter a PSCredential object, such as one generated by the Get-Credential cmdlet.
    # This parameter is valid only when the Proxy parameter is also used in the command. You cannot use the ProxyCredential and ProxyUseDefaultCredentials parameters in the same command.
    [pscredential]
    [Management.Automation.CredentialAttribute()]
    $ProxyCredential,

    # Indicates that the cmdlet uses the credentials of the current user to access the proxy server that is specified by the Proxy parameter.
    # This parameter is valid only when the Proxy parameter is also used in the command. You cannot use the ProxyCredential and ProxyUseDefaultCredentials parameters in the same command.
    [switch]
    $ProxyUseDefaultCredentials
    )

    begin {
        #region Copy Invoke-ADORestAPI parameters
        # Because this command wraps Invoke-ADORestAPI, we want to copy over all shared parameters.
        $invokeRestApi = # To do this, first we get the commandmetadata for Invoke-ADORestAPI.
            [Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand('Invoke-ADORestAPI', 'Function')

        $invokeParams = @{} + $PSBoundParameters # Then we copy our parameters
        foreach ($k in @($invokeParams.Keys)) {  # and walk thru each parameter name.
            # If a parameter isn't found in Invoke-ADORestAPI
            if (-not $invokeRestApi.Parameters.ContainsKey($k)) {
                $invokeParams.Remove($k) # we remove it.
            }
        }
        # We're left with a hashtable containing only the parameters shared with Invoke-ADORestAPI.
        #endregion Copy Invoke-ADORestAPI parameters
    }

    process {
        $goSplat = @{Organization=$Organization;Project=$Project} + $invokeParams


        $invokeParams.Uri = # First construct the URI.  It's made up of:
            "$(@(
                "$server".TrimEnd('/') # * The Server
                $Organization # * The Organization
                $Project # * The Project
                '_apis' #* '_apis'
                'build', #* 'build'
                'builds' #* and 'builds'
            )  -join '/')?$( # Followed by a query string, containing
            @(
                if ($ApiVersion) { # an api-version (if one exists)
                    "api-version=$ApiVersion"
                }
            ) -join '&'
            )"

        $invokeParams.Body = @{}

        if ($DefinitionID) {
            $invokeParams.Body.Definition = @{}
            $invokeParams.Body.Definition.ID = $DefinitionID
        } elseif ($BuildID) {
            $build = Get-ADOBuild -BuildID $BuildID @goSplat
            $invokeParams.Body.Definition = @{}
            $invokeParams.Body.Definition.ID = $build.definition.id
        } elseif ($DefinitionName) {
            $defs = Get-ADOBuild -definition @goSplat |
                Where-Object { $_.Name -like $DefinitionName } |
                Select-Object -First 1
            $invokeParams.Body.Definition = @{}
            $invokeParams.Body.Definition.ID = $defs.ID
        }

        if (-not $invokeParams.Body.Definition.ID) { return}

        if ($SourceBranch) {
            $invokeParams.Body.SourceBranch = $SourceBranch
        }
        if ($SourceVersion) {
            $invokeParams.Body.SourceVersion = $SourceVersion
        }

        if ($Parameter) {
            $invokeParams.Body.Parameters = $Parameter
        }


        $invokeParams.PSTypeName = @( # Prepare a list of typenames so we can customize formatting:
            "$Organization.$Project.Build" # * $Organization.$Project.Build
            "$Organization.Build" # * $Organization.Build
            "StartAutomating.PSDevOps.Build" # * PSDevOps.Build
        )

        $invokeParams.Method = 'POST'

        if ($WhatIfPreference) {
            $invokeParams.Remove('PersonalAccessToken')
            return $invokeParams
        }

        if ($PSCmdlet.ShouldProcess("$($invokeParams.Method) $($invokeParams.Uri)")) {
            Invoke-ADORestAPI @invokeParams -Property @{
                Organization = $Organization
                Project = $Project
            }
        }
    }
}
