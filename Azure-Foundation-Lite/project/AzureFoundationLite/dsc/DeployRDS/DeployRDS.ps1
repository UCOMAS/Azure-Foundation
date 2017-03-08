Configuration RemoteDesktopSessionHost 
{ 
    param 
    ( 
    ) 
    Node "localhost" 
    { 
 
        LocalConfigurationManager 
        { 
            RebootNodeIfNeeded = $true 
        } 
 
        WindowsFeature Remote-Desktop-Services 
        { 
            Ensure = "Present" 
            Name = "Remote-Desktop-Services" 
        } 
 
        WindowsFeature RDS-RD-Server 
        { 
            Ensure = "Present" 
            Name = "RDS-RD-Server" 
        } 

 
        WindowsFeature RSAT-RDS-Tools 
        { 
            Ensure = "Present" 
            Name = "RSAT-RDS-Tools" 
            IncludeAllSubFeature = $true 
        } 
        
 
        WindowsFeature RDS-Licensing 
        { 
            Ensure = "Present" 
            Name = "RDS-Licensing" 
        } 

        WindowsFeature Dns-Tools
	    {
	        Ensure = "Present"
            Name = "RSAT-DNS-Server"
	    }

         WindowsFeature ADDS-Tools            
        {             
            Ensure = "Present"             
            Name = "RSAT-ADDS"             
        }   


        

    } 
} 