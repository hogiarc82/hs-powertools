<#
##############################################################################
# NOTE: THIS SCRIPT WILL NOT CHANGE ANY SYSTEM PROPERTIES IN THE ENVIRONMENT #
##############################################################################
#
#>
<# A user defined function prompting user for selection from a custom menu #>
    # Creates a list with all accessible Azure subscriptions 
    # Creates the option list for the user to select a subscription from
    # Draws the console menu and prompts user for a selection
    # Returns the selected subscription
<# A user defined function for reading the StorageBlobServiceProperty as input #>
    # reads the input from the extended storage properties and selects specific properties 
        #MinRestoreTime        = $obj.RestorePolicy.MinRestoreTime
        #LoggingOperations     = $obj.Logging.LoggingOperations           
        #LogRetentionDays      = $obj.Logging.RetentionDays
# calls Azure RM and returns information about current context
# presents user with a choice to either continue with current context or select a new
# creates a master list (table) for storing all of the storage account properties
# calls Azure RM and returns all storage accounts in the selected subscription
    # skips all storage accounts connected to cloud-shell, webjobs, etc.
        # adding fields to a table row with basic storage account properties
        # retrieves storage account tags and adds them as fields (columns)
        # adding additional storage account properties as new fields (columns)
        # calls a custom defined function to retrieve extended storage properties
        # adding fields related to network access and perimater security, etc.
        # adds the entire row to the master list (table)
# Presents the user with a choice of saving the results to a file or display on screen
    # Outputs table to a file (make sure to include filename and extension)
    #$xlsfile = ".\PSOutputFiles\StorageAccProps.xlsx"
        #$list | Export-Excel -Path $xlsfile -WorksheetName "ExtendedProperties" -TableName "storageprops" -AutoSize
