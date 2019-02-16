#######################################################################################################################
#
# Author: Nayrk
# Date: 12/28/2018
# Last Updated: 2/17/2019
# Purpose: To download all Blink videos locally to the PC. Existing videos will be skipped.
# Output: All Blink videos downloaded in the following directory format.
#         Default Location Desktop - "C:\Users\<UserName>\Desktop"
#         Sub-Folders - Blink --> Home Network Name --> Camera Name #1
#                                                   --> Camera Name #2
#
# Notes: You can change anything below this section.
# Credits: https://github.com/MattTW/BlinkMonitorProtocol
#
#######################################################################################################################

# Change saveDirectory directory if you want the Blink Files to be saved somewhere else, default is user Desktop
$saveDirectory = "C:\Users\$env:UserName\Desktop"

# Blink Credentials. Please fill in!
# Please keep the quotation marks "
$email = "Your Email Here"
$password = "Your Password Here"

# Blink's API Server, this is the URL you are directed to when you are prompted for IFTTT Integration to "Grant Access"
# You can verify this yourself to make sure you are sending the data where you expect it to be
$blinkAPIServer = 'prod.immedia-semi.com'

# Use this server below if you are in Germany. Remove the # symbol below.
# $blinkAPIServer = 'prde.immedia-semi.com'

#######################################################################################################################
#
# Do not change anything below unless you know what you are doing or you want to...
#
#######################################################################################################################

if($email -eq "Your Email Here") { Write-Host 'Please enter your email by modifying the line: $email = "Your Email Here"'; pause; exit;}
if($password -eq "Your Password Here") { Write-Host 'Please enter your password by modifying the line: $password = "Your Password Here"'; pause; exit;}

# Headers to send to Blink's server for authentication
$headers = @{
    "Host" = "$blinkAPIServer"
    "Content-Type" = "application/json"
}

# Credential data to send
$body = @{
    "email" = "$email"
    "password" = "$password"
} | ConvertTo-Json

# Login URL of Blink API
$uri = "https://$blinkAPIServer/login"

# Authenticate credentials with Blink Server and get our token for future requests
$response = Invoke-RestMethod -UseBasicParsing $uri -Method Post -Headers $headers -Body $body
if(-not $response){
    echo "Invalid credentials provided. Please verify email and password."
    pause
    exit
}

# Get the object data
$region = $response.region.psobject.properties.name
$authToken = $response.authtoken.authtoken

# Headers to send to Blink's server after authentication with our token
$headers = @{
    "Host" = "$blinkAPIServer"
    "TOKEN_AUTH" = "$authToken"
}

# Get list of networks
$uri = 'https://rest-'+ $region +'.immedia-semi.com/networks/'
$networks = Invoke-RestMethod -UseBasicParsing $uri -Method Get -Headers $headers
#echo $networks.summary.psobject.properties.name
#exit

# Iterate each network for cameras attached and create the sub-folders
foreach($network_id in $networks.summary.psobject.properties.name)
{
    #echo "==========================================="
    $networkName = $networks.summary.$network_id.name
    #echo "Network: $networkName"
    $uri = 'https://rest-'+ $region +".immedia-semi.com/network/$network_id/cameras"
    $cameras = Invoke-RestMethod -UseBasicParsing $uri -Method Get -Headers $headers
    foreach($camera in $cameras.devicestatus){
        $cameraThumbnail = $camera.thumbnail
        $cameraName = $camera.name
        #echo "Camera: $cameraName"
        #echo "Thumbnail: $cameraThumbnail"
        #echo ""

        # Create Blink Directory to store videos if it doesn't exist
        $path = "$saveDirectory\Blink\$networkName\$cameraName"
        if (-not (Test-Path $path)){
            $folder = New-Item  -ItemType Directory -Path $path
        }

        # Download camera thumbnail
        $thumbURL = 'https://rest-'+ $region +'.immedia-semi.com' + $cameraThumbnail + ".jpg"
        $thumbPath = "$path\" + "thumbnail_" + $cameraThumbnail.Split("/")[-1] + ".jpg"
        #echo $thumbPath
        # Skip if already downloaded
        if (-not (Test-Path $thumbPath)){
            echo "Downloading thumbnail for $cameraName camera in $networkName."
            Invoke-RestMethod -UseBasicParsing $thumbURL -Method Get -Headers $headers -OutFile $thumbPath
        }
    }
}
#exit

$pageNum = 1

# Continue to download videos from each page until all are downloaded
while ( 1 )
{
    # List of videos from Blink's server
    # $uri = 'https://rest-'+ $region +'.immedia-semi.com/api/v2/videos/page/' + $pageNum
    
    # Changed to use old endpoint
    $uri = 'https://rest-'+ $region +'.immedia-semi.com/api/v2/videos/changed?since=2016-01-01T23:11:21+0000&page=' + $pageNum

    # Get the list of video clip information from each page from Blink
    $response = Invoke-RestMethod -UseBasicParsing $uri -Method Get -Headers $headers
    
    # No more videos to download, exit from loop
    if(-not $response.videos){
        break
    }

    # Go through each video information and get the download link and relevant information
    foreach($video in $response.videos){
        # Video clip information
        $address = $video.address
        $timestamp = $video.created_at
        $network = $video.network_name
        $camera = $video.camera_name
        $camera_id = $video.camera_id
       
        # Get video timestamp in local time
        $videoTime = Get-Date -Date $timestamp -Format "yyyy-MM-dd_HH-mm-ss"

        # Download address of video clip
        $videoURL = 'https://rest-'+ $region +'.immedia-semi.com' + $address
        
        # Download video if it is new
        $path = "$saveDirectory\Blink\$network\$camera"
        $videoPath = "$path\$videoTime.mp4"
        if (-not (Test-Path $videoPath)){
            echo "Downloading video for $camera camera in $network."
            Invoke-RestMethod -UseBasicParsing $videoURL -Method Get -Headers $headers -OutFile $videoPath           
        }
    }
    $pageNum += 1
}
echo "All new videos and thumbnails downloaded to $saveDirectory\Blink\"

# Remove "pause" command below for automation through Windows Scheduler
pause
