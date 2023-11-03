@description('The name of the Azure Function app.')
param functionAppName string = 'VaronisDSP-${uniqueString(resourceGroup().id)}'

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Location for Application Insights')
param appInsightsLocation string = resourceGroup().location

@description('The language worker runtime to load in the function app.')
@allowed([
  'dotnet'
  'node'
  'python'
  'java'
])
param functionWorkerRuntime string = 'dotnet'

@description('Specifies the OS used for the Azure Function hosting plan.')
@allowed([
  'Windows'
  'Linux'
])
param functionPlanOS string = 'Linux'

@description('Specifies the Azure Function hosting plan SKU.')
@allowed([
  'EP1'
  'EP2'
  'EP3'
])
param functionAppPlanSku string = 'EP1'

@description('The zip content url.')
param packageUri string = 'https://github.com/vkorenkov-varonis/sentinel/raw/master/Varonis.Sentinel.Functions.zip'

@description('Only required for Linux app to represent runtime stack in the format of \'runtime|runtimeVersion\'. For example: \'python|3.9\'')
param linuxFxVersion string = 'DOTNET|6.0'

@description('Name of the Log Analytics workspace used by Microsoft Sentinel.')
param logAnalyticsWorkspaceName string

@description('Varonis DatAlert host name.')
param datAlertHostName string

@secure()
@description('Varonis DatAlert API key.')
param datAlertApiKey string

@description('The friendly name for the workbook that is used in the Gallery or Saved List.  This name must be unique within a resource group.')
param workbookDisplayName string = 'Varonis Data Security Platform'

@description('The unique id for this workbook instance')
param workbookId string = newGuid()

var hostingPlanName = functionAppName
var applicationInsightsName = functionAppName
var storageAccountName = '${uniqueString(resourceGroup().id)}azfunctions'
var isReserved = ((functionPlanOS == 'Linux') ? true : false)
var workbookSourceId = logAnalyticsWorkspace.id

// Reference the existing Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    tier: 'ElasticPremium'
    name: functionAppPlanSku
    family: 'EP'
  }
  properties: {
    maximumElasticWorkerCount: 20
    reserved: isReserved
  }
  kind: 'elastic'
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: appInsightsLocation
  tags: {
    'hidden-link:${resourceId('Microsoft.Web/sites', applicationInsightsName)}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
  }
  kind: 'web'
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: (isReserved ? 'functionapp,linux' : 'functionapp')
  properties: {
    reserved: isReserved
    serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: (isReserved ? linuxFxVersion : null)
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: packageUri
        }
        {
          name: 'DatAlertHostName'
          value: datAlertHostName
        }
        {
          name: 'DatAlertApiKey'
          value: datAlertApiKey
        }
        {
          name: 'LogAnalyticsKey'
          value: logAnalyticsWorkspace.listKeys().primarySharedKey
        }
        {
          name: 'LogAnalyticsWorkspace'
          value: logAnalyticsWorkspace.properties.customerId
        }
        {
          name: 'FirstFetchTime'
          value: '2 weeks'
        }
        {
          name: 'MinSeverityLevel'
          value: 'Low, Medium, High'
        }
        {
          name: 'ThreatModelNameList'
          value: ''
        }
      ]
    }
  }
}

resource workbookId_resource 'microsoft.insights/workbooks@2022-04-01' = {
  name: workbookId
  location: location
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: '{"version":"Notebook/1.0","items":[{"type":9,"content":{"version":"KqlParameterItem/1.0","parameters":[{"id":"388e603c-a5b1-40db-808f-d5dc5301793e","version":"KqlParameterItem/1.0","name":"time_range","label":"TimeRange","type":4,"isRequired":true,"typeSettings":{"selectableValues":[{"durationMs":300000},{"durationMs":900000},{"durationMs":1800000},{"durationMs":3600000},{"durationMs":14400000},{"durationMs":43200000},{"durationMs":86400000},{"durationMs":172800000},{"durationMs":259200000},{"durationMs":604800000},{"durationMs":1209600000},{"durationMs":2419200000},{"durationMs":2592000000},{"durationMs":5184000000},{"durationMs":7776000000}],"allowCustom":true},"timeContext":{"durationMs":86400000},"value":{"durationMs":259200000}},{"id":"e1c3e667-d431-419e-ae03-2da2f7f2d42f","version":"KqlParameterItem/1.0","name":"page","label":"Page","type":1,"isGlobal":true,"isHiddenWhenLocked":true,"value":"main"}],"style":"pills","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces"},"name":"global-parameters"},{"type":11,"content":{"version":"LinkItem/1.0","style":"tabs","links":[{"id":"30fe89ad-9eba-419e-8d9e-53c6805870db","cellValue":"page","linkTarget":"parameter","linkLabel":"Main","subTarget":"main","preText":"Main","style":"link"},{"id":"5822aaf8-5ad8-49c6-acf8-491b439fbc1a","cellValue":"page","linkTarget":"parameter","linkLabel":"Threats","subTarget":"threats","style":"link"},{"id":"7266371b-70ac-4b79-abda-43169b26d760","cellValue":"page","linkTarget":"parameter","linkLabel":"Users","subTarget":"users","style":"link"},{"id":"3e007191-772f-48aa-8ac0-dfc9947f85c7","cellValue":"page","linkTarget":"parameter","linkLabel":"Assets","subTarget":"assets","style":"link"},{"id":"e585bed2-37bc-4bfe-8269-cd12726a8fe9","cellValue":"page","linkTarget":"parameter","linkLabel":"Devices","subTarget":"devices","style":"link"}]},"name":"links - 6"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":3,"content":{"version":"KqlItem/1.0","query":"let days = dynamic([\\"Sun\\", \\"Mon\\", \\"Tue\\", \\"Wed\\", \\"Thu\\", \\"Fri\\", \\"Sat\\"]);\\nlet months = dynamic([\\"Jan\\", \\"Feb\\", \\"Mar\\", \\"Apr\\", \\"May\\", \\"Jun\\", \\"Jul\\", \\"Aug\\", \\"Sep\\", \\"Oct\\", \\"Nov\\", \\"Dec\\"]);\\nVaronisAlerts_CL\\n| extend day_of_week = days[toint(dayofweek(EventUTC_t)/1d)]\\n| extend month_of_year = months[getmonth(EventUTC_t)]\\n| extend day_of_month = dayofmonth(EventUTC_t)\\n| extend day_str = strcat(day_of_week, \\" \\", month_of_year, \\" \\", day_of_month)\\n| extend day = todatetime(format_datetime(EventUTC_t, \'yyyy-MM-dd\'))\\n| summarize alert_count = count() by day, day_str, Severity_s\\n| order by day asc, Severity_s\\n| project Day = day_str, Alerts = alert_count, Severity = Severity_s","size":1,"title":"ALERTS OVER TIME","timeContextFromParameter":"time_range","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","visualization":"barchart","chartSettings":{"xAxis":"Day","yAxis":["Alerts"],"group":"Severity","createOtherGroup":null,"showLegend":true}},"name":"ALERTS OVER TIME - Copy"},{"type":3,"content":{"version":"KqlItem/1.0","query":"VaronisAlerts_CL\\r\\n| where  isnotempty( Name_s)\\r\\n| summarize alerts_count = count() by Name_s\\r\\n| project Threat = Name_s, Alerts = alerts_count\\r\\n| take 4","size":0,"title":"TOP ALERTED THREAT MODELS","timeContextFromParameter":"time_range","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","visualization":"tiles","tileSettings":{"titleContent":{"columnMatch":"Threat","formatter":1},"leftContent":{"columnMatch":"Alerts","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}},"showBorder":false,"sortCriteriaField":"Alerts","sortOrderField":2,"size":"full"},"mapSettings":{"locInfo":"LatLong","sizeSettings":"Alerts","sizeAggregation":"Sum","legendMetric":"Alerts","legendAggregation":"Sum","itemColorSettings":{"type":"heatmap","colorAggregation":"Sum","nodeColorField":"Alerts","heatmapPalette":"greenRed"}}},"customWidth":"50","name":"TOP ALERTED THREAT MODELS"},{"type":3,"content":{"version":"KqlItem/1.0","query":"VaronisAlerts_CL\\r\\n| extend json_arr = parse_json(UserName_s)\\r\\n| where  isnotempty(json_arr)\\r\\n| mv-expand json_arr\\r\\n| summarize alerts_count = count() by tostring(json_arr)\\r\\n| project User = json_arr, Alerts = alerts_count\\r\\n| take 4","size":0,"title":" TOP ALERTED USERS","timeContextFromParameter":"time_range","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","visualization":"tiles","tileSettings":{"titleContent":{"columnMatch":"User","formatter":1},"leftContent":{"columnMatch":"Alerts","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}},"showBorder":false,"sortCriteriaField":"Alerts","sortOrderField":2,"size":"full"},"mapSettings":{"locInfo":"LatLong","sizeSettings":"Alerts","sizeAggregation":"Sum","legendMetric":"Alerts","legendAggregation":"Sum","itemColorSettings":{"type":"heatmap","colorAggregation":"Sum","nodeColorField":"Alerts","heatmapPalette":"greenRed"}}},"customWidth":"50","name":" TOP ALERTED USERS"},{"type":3,"content":{"version":"KqlItem/1.0","query":"VaronisAlerts_CL\\r\\n| extend json_arr = parse_json(Asset_s)\\r\\n| where  isnotempty(json_arr)\\r\\n| mv-expand json_arr\\r\\n| summarize alerts_count = count() by tostring(json_arr)\\r\\n| project Asset = json_arr, Alerts = alerts_count\\r\\n| take 4","size":0,"title":"TOP ALERTED ASSETS","timeContextFromParameter":"time_range","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","visualization":"tiles","tileSettings":{"titleContent":{"columnMatch":"Asset","formatter":1},"leftContent":{"columnMatch":"Alerts","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}},"showBorder":false,"sortCriteriaField":"Alerts","sortOrderField":2,"size":"full"},"mapSettings":{"locInfo":"LatLong","sizeSettings":"Alerts","sizeAggregation":"Sum","legendMetric":"Alerts","legendAggregation":"Sum","itemColorSettings":{"type":"heatmap","colorAggregation":"Sum","nodeColorField":"Alerts","heatmapPalette":"greenRed"}}},"customWidth":"50","name":"TOP ALERTED ASSETS"},{"type":3,"content":{"version":"KqlItem/1.0","query":"VaronisAlerts_CL\\r\\n| extend json_arr = parse_json(DeviceName_s)\\r\\n| where  isnotempty(json_arr)\\r\\n| mv-expand json_arr\\r\\n| summarize alerts_count = count() by tostring(json_arr)\\r\\n| project Device = json_arr, Alerts = alerts_count\\r\\n| take 4","size":0,"title":"TOP ALERTED DEVICES","timeContextFromParameter":"time_range","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","visualization":"tiles","tileSettings":{"titleContent":{"columnMatch":"Device","formatter":1},"leftContent":{"columnMatch":"Alerts","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}},"showBorder":false,"sortCriteriaField":"Alerts","sortOrderField":2,"size":"full"},"mapSettings":{"locInfo":"LatLong","sizeSettings":"Alerts","sizeAggregation":"Sum","legendMetric":"Alerts","legendAggregation":"Sum","itemColorSettings":{"type":"heatmap","colorAggregation":"Sum","nodeColorField":"Alerts","heatmapPalette":"greenRed"}}},"customWidth":"50","name":"TOP ALERTED DEVICES"}]},"conditionalVisibility":{"parameterName":"page","comparison":"isEqualTo","value":"main"},"name":"main-page"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":3,"content":{"version":"KqlItem/1.0","query":"let days = dynamic([\\"Sun\\", \\"Mon\\", \\"Tue\\", \\"Wed\\", \\"Thu\\", \\"Fri\\", \\"Sat\\"]);\\nlet months = dynamic([\\"Jan\\", \\"Feb\\", \\"Mar\\", \\"Apr\\", \\"May\\", \\"Jun\\", \\"Jul\\", \\"Aug\\", \\"Sep\\", \\"Oct\\", \\"Nov\\", \\"Dec\\"]);\\nVaronisAlerts_CL\\n| extend day_of_week = days[toint(dayofweek(EventUTC_t)/1d)]\\n| extend month_of_year = months[getmonth(EventUTC_t)]\\n| extend day_of_month = dayofmonth(EventUTC_t)\\n| extend day_str = strcat(day_of_week, \\" \\", month_of_year, \\" \\", day_of_month)\\n| extend day = todatetime(format_datetime(EventUTC_t, \'yyyy-MM-dd\'))\\n| extend group_var = Name_s\\n| summarize alert_count = count() by day, day_str, group_var\\n| order by day asc, group_var\\n| project Day = day_str, Alerts = alert_count, Threat = group_var\\n","size":1,"title":"THREAT MODEL NAMES","timeContextFromParameter":"time_range","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","visualization":"barchart","chartSettings":{"xAxis":"Day","yAxis":["Alerts"],"group":"Threat","createOtherGroup":null,"showLegend":true}},"name":"alerts-threats-day"}]},"conditionalVisibility":{"parameterName":"page","comparison":"isEqualTo","value":"threats"},"name":"threats-page"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":3,"content":{"version":"KqlItem/1.0","query":"let days = dynamic([\\"Sun\\", \\"Mon\\", \\"Tue\\", \\"Wed\\", \\"Thu\\", \\"Fri\\", \\"Sat\\"]);\\nlet months = dynamic([\\"Jan\\", \\"Feb\\", \\"Mar\\", \\"Apr\\", \\"May\\", \\"Jun\\", \\"Jul\\", \\"Aug\\", \\"Sep\\", \\"Oct\\", \\"Nov\\", \\"Dec\\"]);\\nVaronisAlerts_CL\\n| extend day_of_week = days[toint(dayofweek(EventUTC_t)/1d)]\\n| extend month_of_year = months[getmonth(EventUTC_t)]\\n| extend day_of_month = dayofmonth(EventUTC_t)\\n| extend day_str = strcat(day_of_week, \\" \\", month_of_year, \\" \\", day_of_month)\\n| extend day = todatetime(format_datetime(EventUTC_t, \'yyyy-MM-dd\'))\\n| extend json_arr = parse_json(UserName_s)\\n| where  isnotempty(json_arr)\\n| mv-expand json_arr\\n| extend group_var = tostring(json_arr)\\n| summarize alert_count = count() by day, day_str, group_var\\n| order by day asc, group_var\\n| project Day = day_str, Alerts = alert_count, User = group_var","size":1,"title":"USERS","timeContextFromParameter":"time_range","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","visualization":"barchart","chartSettings":{"xAxis":"Day","yAxis":["Alerts"],"group":"User","createOtherGroup":null,"showLegend":true}},"name":"alerts-users-day"}]},"conditionalVisibility":{"parameterName":"page","comparison":"isEqualTo","value":"users"},"name":"users-page"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":3,"content":{"version":"KqlItem/1.0","query":"let days = dynamic([\\"Sun\\", \\"Mon\\", \\"Tue\\", \\"Wed\\", \\"Thu\\", \\"Fri\\", \\"Sat\\"]);\\nlet months = dynamic([\\"Jan\\", \\"Feb\\", \\"Mar\\", \\"Apr\\", \\"May\\", \\"Jun\\", \\"Jul\\", \\"Aug\\", \\"Sep\\", \\"Oct\\", \\"Nov\\", \\"Dec\\"]);\\nVaronisAlerts_CL\\n| extend day_of_week = days[toint(dayofweek(EventUTC_t)/1d)]\\n| extend month_of_year = months[getmonth(EventUTC_t)]\\n| extend day_of_month = dayofmonth(EventUTC_t)\\n| extend day_str = strcat(day_of_week, \\" \\", month_of_year, \\" \\", day_of_month)\\n| extend day = todatetime(format_datetime(EventUTC_t, \'yyyy-MM-dd\'))\\n| extend json_arr = parse_json(Asset_s)\\n| where  isnotempty(json_arr)\\n| mv-expand json_arr\\n| extend group_var = tostring(json_arr)\\n| summarize alert_count = count() by day, day_str, group_var\\n| order by day asc, group_var\\n| project Day = day_str, Alerts = alert_count, Asset = group_var","size":1,"title":"ASSETS","timeContextFromParameter":"time_range","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","visualization":"barchart","chartSettings":{"xAxis":"Day","yAxis":["Alerts"],"group":"Asset","createOtherGroup":null,"showLegend":true}},"name":"alerts-assets"}]},"conditionalVisibility":{"parameterName":"page","comparison":"isEqualTo","value":"assets"},"name":"assets-page"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":3,"content":{"version":"KqlItem/1.0","query":"let days = dynamic([\\"Sun\\", \\"Mon\\", \\"Tue\\", \\"Wed\\", \\"Thu\\", \\"Fri\\", \\"Sat\\"]);\\nlet months = dynamic([\\"Jan\\", \\"Feb\\", \\"Mar\\", \\"Apr\\", \\"May\\", \\"Jun\\", \\"Jul\\", \\"Aug\\", \\"Sep\\", \\"Oct\\", \\"Nov\\", \\"Dec\\"]);\\nVaronisAlerts_CL\\n| extend day_of_week = days[toint(dayofweek(EventUTC_t)/1d)]\\n| extend month_of_year = months[getmonth(EventUTC_t)]\\n| extend day_of_month = dayofmonth(EventUTC_t)\\n| extend day_str = strcat(day_of_week, \\" \\", month_of_year, \\" \\", day_of_month)\\n| extend day = todatetime(format_datetime(EventUTC_t, \'yyyy-MM-dd\'))\\n| extend json_arr = parse_json(DeviceName_s)\\n| where  isnotempty(json_arr)\\n| mv-expand json_arr\\n| extend group_var = tostring(json_arr)\\n| summarize alert_count = count() by day, day_str, group_var\\n| order by day asc, group_var\\n| project Day = day_str, Alerts = alert_count, Device = group_var\\n","size":1,"title":"DEVICES","timeContextFromParameter":"time_range","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","visualization":"barchart","chartSettings":{"xAxis":"Day","yAxis":["Alerts"],"group":"Device","createOtherGroup":null,"showLegend":true}},"name":"alerts-devices-day"}]},"conditionalVisibility":{"parameterName":"page","comparison":"isEqualTo","value":"devices"},"name":"devices-page"}],"isLocked":false,"fallbackResourceIds":["/subscriptions/4aef56e4-24c5-49ca-9ce1-b6123134b874/resourcegroups/vrns_sentinel_data_alert_rg/providers/microsoft.operationalinsights/workspaces/vrns-log-analytics-api-ws"],"fromTemplateId":"https://sentinelus.hosting.portal.azure.net/sentinelus/Content/1.0.02484.3403-231021-003920/Scenarios/Ecosystem/Content/Workbooks/CustomWorkbook.json"}'
    version: '1.0'
    sourceId: workbookSourceId
    category: 'sentinel'
  }
  dependsOn: []
}

output workbookId string = workbookId_resource.id
