type FileTransferRequest record {|
    string fileName;
    int fileSize;
    string sourceLocation;
    string destinationLocation;
    string transferStatus;
|};