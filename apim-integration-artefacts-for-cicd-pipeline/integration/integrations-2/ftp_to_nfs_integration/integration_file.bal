// Scheduled service to transfer files from FTP to NFS
// Runs every minute to check for new files

import ballerina/ftp;
import ballerina/io;
import ballerina/log;
import ballerina/file;
import ballerina/lang.runtime;

// Local temporary directory for file processing
const string TEMP_DIR = "./temp_transfer";

// Track last processed file to avoid duplicates
string lastProcessedFile = "";

// FTP Client
final ftp:Client ftpClient = check new ({
    protocol: ftp:FTP,
    host: ftpHost,
    port: ftpPort,
    auth: {
        credentials: {
            username: ftpUsername,
            password: ftpPassword
        }
    }
});

// Initialize the scheduled service
// NOTE: This main function will block other services from running
// To run WebSocket service, either:
// 1. Comment out this main function, or
// 2. Run this file separately: bal run integration_file.bal
public function main() returns error? {
    
    // Create temp directory if it doesn't exist
    check createTempDirectory();
    
    log:printInfo("Starting scheduled file transfer service...");
    log:printInfo(string `FTP: ${ftpHost}:${ftpPort}${ftpDirectory}`);
    log:printInfo(string `NFS: nfs://${nfsHost}:${nfsPort}${nfsDirectory}`);
    log:printInfo("Checking for new files every minute...");
    
    // Run the scheduled task every minute
    while true {
        error? result = processFileTransfer();
        if result is error {
            log:printError(string `File transfer failed: ${result.message()}`);
        }
        
        // Wait for 60 seconds (1 minute)
        runtime:sleep(60);
    }
}

// Process file transfer from FTP to SMB
function processFileTransfer() returns error? {
    
    log:printInfo("Checking FTP for new files...");
    
    // List files in FTP directory
    ftp:FileInfo[]|ftp:Error fileList = ftpClient->list(ftpDirectory);
    
    if fileList is ftp:Error {
        log:printError(string `Failed to list FTP files: ${fileList.message()}`);
        return fileList;
    }
    
    if fileList.length() == 0 {
        log:printInfo("No files found in FTP directory");
        return;
    }
    
    // Find the latest file (by lastModifiedTimestamp)
    ftp:FileInfo? latestFile = findLatestFile(fileList);
    
    if latestFile is () {
        log:printInfo("No valid files found");
        return;
    }
    
    // Check if this file was already processed
    if latestFile.name == lastProcessedFile {
        log:printInfo(string `Latest file '${latestFile.name}' already processed`);
        return;
    }
    
    log:printInfo(string `Found new file: ${latestFile.name} (${latestFile.size} bytes)`);
    
    // Download file from FTP
    string ftpFilePath = string `${ftpDirectory}/${latestFile.name}`;
    string localFilePath = string `${TEMP_DIR}/${latestFile.name}`;
    
    error? downloadResult = downloadFromFtp(ftpFilePath = ftpFilePath, localPath = localFilePath);
    if downloadResult is error {
        log:printError(string `Failed to download file: ${downloadResult.message()}`);
        return downloadResult;
    }
    
    log:printInfo(string `Downloaded file to: ${localFilePath}`);
    
    // Upload file to NFS
    error? uploadResult = uploadToNfs(localPath = localFilePath, fileName = latestFile.name);
    if uploadResult is error {
        log:printError(string `Failed to upload to NFS: ${uploadResult.message()}`);
        return uploadResult;
    }
    
    log:printInfo(string `Successfully transferred '${latestFile.name}' from FTP to NFS`);
    
    // Log transfer to database
    FileTransferRequest transferRecord = {
        fileName: latestFile.name,
        fileSize: latestFile.size,
        sourceLocation: string `ftp://${ftpHost}:${ftpPort}${ftpDirectory}`,
        destinationLocation: string `nfs://${nfsHost}:${nfsPort}${nfsDirectory}`,
        transferStatus: "SUCCESS"
    };
    
     
    // Update last processed file
    lastProcessedFile = latestFile.name;
    
    // Clean up local temp file
    error? deleteResult = file:remove(localFilePath);
    if deleteResult is error {
        log:printWarn(string `Failed to delete temp file: ${deleteResult.message()}`);
    }
}

// Find the latest file from the list
function findLatestFile(ftp:FileInfo[] files) returns ftp:FileInfo? {
    
    ftp:FileInfo? latest = ();
    int latestTimestamp = 0;
    
    foreach ftp:FileInfo fileInfo in files {
        // Skip directories
        if fileInfo.isFolder {
            continue;
        }
        
        if fileInfo.lastModifiedTimestamp > latestTimestamp {
            latestTimestamp = fileInfo.lastModifiedTimestamp;
            latest = fileInfo;
        }
    }
    
    return latest;
}

// Download file from FTP
function downloadFromFtp(string ftpFilePath, string localPath) returns error? {
    
    stream<byte[] & readonly, io:Error?>|ftp:Error fileStream = ftpClient->get(ftpFilePath);
    
    if fileStream is ftp:Error {
        return error(string `FTP get failed: ${fileStream.message()}`);
    }
    
    // Read all bytes from stream
    byte[] fileContent = [];
    
    error? streamResult = fileStream.forEach(function(byte[] & readonly chunk) {
        foreach byte b in chunk {
            fileContent.push(b);
        }
    });
    
    if streamResult is error {
        return error(string `Failed to read FTP stream: ${streamResult.message()}`);
    }
    
    // Write to local file
    io:Error? writeResult = io:fileWriteBytes(localPath, fileContent);
    
    if writeResult is io:Error {
        return error(string `Failed to write local file: ${writeResult.message()}`);
    }
    
    return;
}

// Upload file to NFS
// Writes directly to the NFS mount point
function uploadToNfs(string localPath, string fileName) returns error? {
    
    // Read the local file
    byte[]|io:Error fileContent = io:fileReadBytes(localPath);
    
    if fileContent is io:Error {
        return error(string `Failed to read local file: ${fileContent.message()}`);
    }
    
    // Write directly to NFS mount point
    // The NFS share is mounted at nfsMountPoint (e.g., /Users/ramindu/Desktop/nfs-mount-test)
    // Files written to nfsMountPoint will appear in the NFS server's nfsDirectory
    string targetPath = string `${nfsMountPoint}/${fileName}`;
    
    // Write file to NFS location
    io:Error? writeResult = io:fileWriteBytes(targetPath, fileContent);
    
    if writeResult is io:Error {
        return error(string `Failed to write to NFS: ${writeResult.message()}`);
    }
    
    log:printInfo(string `File saved to NFS mount: ${targetPath}`);
    log:printInfo(string `NFS URL: nfs://${nfsHost}:${nfsPort}${nfsDirectory}/${fileName}`);
    
    return;
}

// Create temporary directory for file processing
function createTempDirectory() returns error? {
    error? result = file:createDir(TEMP_DIR, file:NON_RECURSIVE);
    if result is error {
        // Directory might already exist, which is fine
        log:printInfo("Temp directory already exists or created");
    }
    return;
}