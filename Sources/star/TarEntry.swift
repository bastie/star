/**
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License. 
 * You may obtain a copy of the License at 
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0 
 * 
 * Unless required by applicable law or agreed to in writing, software 
 * distributed under the License is distributed on an "AS IS" BASIS, 
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
 * See the License for the specific language governing permissions and 
 * limitations under the License. 
 * 
 */

import JavApi

/**
 * @author Kamran Zafar
 * 
 */
open class TarEntry {
  public var file : java.io.File?
  public var header : TarHeader
  
  private init() {
    self.file = nil
    self.header = TarHeader()
  }
  
  public convenience init(_ file : java.io.File, _ entryName : String) {
    self.init()
    self.file = file
    self.extractTarHeader(entryName)
  }
  
  public convenience init(_ headerBuf : [UInt8]) {
    self.init()
    self.parseTarHeader(headerBuf)
  }
  
  /**
   * Constructor to create an entry from an existing TarHeader object.
   *
   * This method is useful to add new entries programmatically (e.g. for
   * adding files or directories that do not exist in the file system).
   */
  public init (_ header : TarHeader) {
    self.file = nil;
    self.header = header;
  }
  
  public func equals(_ it : Any) -> Bool {
    if (!(it is TarEntry)) {
      return false;
    }
    let itAsTarEntry = it as! TarEntry
    return header.name.toString().equals(itAsTarEntry.header.name.toString())
  }
  
  public func hashCode() -> Int {
    return header.name.hashCode();
  }
  
  public func isDescendent(_ desc : TarEntry) -> Bool{
    return desc.header.name.toString().startsWith(header.name.toString())
  }
  
  public func getHeader() -> TarHeader{
    return header
  }
  
  public func getName() -> String {
    var name = header.name.toString();
    if (!header.namePrefix.toString().equals("")) {
      name = header.namePrefix.toString() + "/" + name
    }
    
    return name
  }
  
  public func setName(_ name : String) {
    header.name = StringBuilder(name)
  }
  
  public func getUserId() -> Int{
    return header.userId;
  }
  
  public func setUserId(_ userId : Int) {
    header.userId = userId;
  }
  
  public func getGroupId() -> Int {
    return header.groupId;
  }
  
  public func setGroupId(_ groupId : Int) {
    header.groupId = groupId;
  }
  
  public func getUserName() -> String {
    return header.userName.toString();
  }
  
  public func setUserName(_ userName : String) {
    header.userName = StringBuilder(userName);
  }
  
  public func getGroupName() -> String{
    return header.groupName.toString();
  }
  
  public func setGroupName(_ groupName : String) {
    header.groupName = StringBuilder(groupName);
  }
  
  public func setIds(_ userId : Int, _ groupId : Int) {
    self.setUserId(userId);
    self.setGroupId(groupId);
  }
  
  public func setModTime(_ time : Int64) {
    header.modTime = time / 1000 // Java works with milliseconds instead of seconds
  }
  
  public func setModTime(_ time : java.util.Date) {
    header.modTime = time.getTime() / 1000 // Java works with milliseconds instead of seconds
  }
  
  public func getModTime() -> java.util.Date {
    return java.util.Date(header.modTime * 1000) // Java works with milliseconds instead of seconds
  }
  
  public func getFile() -> java.io.File? {
    return self.file;
  }
  
  public func getSize() -> Int64 {
    return header.size;
  }
  
  public func setSize(_ size : Int64) {
    header.size = size;
  }
  
  /**
   * Checks if the org.kamrazafar.jtar entry is a directory
   */
  public func isDirectory() -> Bool{
    if (self.file != nil) {
      return self.file!.isDirectory();
    }
    
    //if (header != nil) {
      if (header.typeflag == TarHeader.LF_DIR) {
        return true;
      }
      
      if (header.name.toString().endsWith("/")) {
        return true;
      }
    //}
    
    return false;
  }
  
  /**
   * Extract header from File
   */
  public func extractTarHeader(_ entryName : String) {
    let permissions : Int = file!.isDirectory() ? 0755 : 0644;  // Default umask
    header = TarHeader.createHeader(entryName, file!.length(), file!.lastModified() / Int64(1000), file!.isDirectory(), permissions) // Java works with milliseconds instead of seconds
  }
  
  /**
   * Calculate checksum
   */
  public func computeCheckSum(_ buf : [UInt8]) -> Int64 {
    /*long sum = 0;
    
    for (int i = 0; i < buf.length; ++i) {
      sum += 255 & buf[i];
    }*/
    let sum : Int64 = buf.reduce(0) { $0 + Int64($1) } // Basties TODO: test it

    return sum;
  }
  
  /**
   * Writes the header to the byte buffer
   */
  public func writeEntryHeader(_ outbuf : inout [UInt8]){
    var offset : Int = 0;
    
    offset = TarHeader.getStringBytes(header.name, outbuf, offset, TarHeader.NAMELEN);
    offset = Octal.getOctalBytes(Int64(header.mode), &outbuf, offset, TarHeader.MODELEN);
    offset = Octal.getOctalBytes(Int64(header.userId), &outbuf, offset, TarHeader.UIDLEN);
    offset = Octal.getOctalBytes(Int64(header.groupId), &outbuf, offset, TarHeader.GIDLEN);
    offset = Octal.getOctalBytes(header.size, &outbuf, offset, TarHeader.SIZELEN);
    offset = Octal.getOctalBytes(header.modTime, &outbuf, offset, TarHeader.MODTIMELEN);
    
    outbuf.replaceSubrange(offset..<offset+TarHeader.CHKSUMLEN, with: repeatElement(UInt8(ascii: " "), count: TarHeader.CHKSUMLEN))
    
    let csOffset : Int = offset;
    offset += TarHeader.CHKSUMLEN;
    
    outbuf[offset] = header.typeflag;
    offset += 1

    offset = TarHeader.getStringBytes(header.linkName, outbuf, offset, TarHeader.NAMELEN);
    offset = TarHeader.getStringBytes(header.magic, outbuf, offset, TarHeader.USTAR_MAGICLEN);
    offset = TarHeader.getStringBytes(header.userName, outbuf, offset, TarHeader.USTAR_USER_NAMELEN);
    offset = TarHeader.getStringBytes(header.groupName, outbuf, offset, TarHeader.USTAR_GROUP_NAMELEN);
    /* Java does not support blocks and character files, ignore */
    // offset = Octal.getOctalBytes(header.devMajor, outbuf, offset, TarHeader.USTAR_DEVLEN);
    // offset = Octal.getOctalBytes(header.devMinor, outbuf, offset, TarHeader.USTAR_DEVLEN);
    offset += TarHeader.USTAR_DEVLEN * 2;
    offset = TarHeader.getStringBytes(header.namePrefix, outbuf, offset, TarHeader.USTAR_FILENAME_PREFIX);
    
    while offset < outbuf.length {
      outbuf[offset] = 0
      offset += 1
    }
    
    let checkSum : Int64 = self.computeCheckSum(outbuf);
    
    _ = Octal.getCheckSumOctalBytes(checkSum, &outbuf, csOffset, TarHeader.CHKSUMLEN);
  }
  
  /**
   * Parses the tar header to the byte buffer
   */
  public func parseTarHeader(_ bh : [UInt8]) {
    var offset = 0;
    
    header.name = TarHeader.parseString(bh, offset, TarHeader.NAMELEN);
    offset += TarHeader.NAMELEN;
    
    header.mode = Int (Octal.parseOctal(bh, offset, TarHeader.MODELEN))
    offset += TarHeader.MODELEN;
    
    header.userId = Int (Octal.parseOctal(bh, offset, TarHeader.UIDLEN))
    offset += TarHeader.UIDLEN;
    
    header.groupId = Int (Octal.parseOctal(bh, offset, TarHeader.GIDLEN))
    offset += TarHeader.GIDLEN;
    
    header.size = Octal.parseOctal(bh, offset, TarHeader.SIZELEN)
    offset += TarHeader.SIZELEN;
    
    header.modTime = Octal.parseOctal(bh, offset, TarHeader.MODTIMELEN)
    offset += TarHeader.MODTIMELEN;
    
    header.checkSum = Int (Octal.parseOctal(bh, offset, TarHeader.CHKSUMLEN))
    offset += TarHeader.CHKSUMLEN;
    
    header.typeflag = bh[offset];
                           offset += 1
    
    header.linkName = TarHeader.parseString(bh, offset, TarHeader.NAMELEN);
    offset += TarHeader.NAMELEN;
    
    header.magic = TarHeader.parseString(bh, offset, TarHeader.USTAR_MAGICLEN);
    offset += TarHeader.USTAR_MAGICLEN;
    
    header.userName = TarHeader.parseString(bh, offset, TarHeader.USTAR_USER_NAMELEN);
    offset += TarHeader.USTAR_USER_NAMELEN;
    
    header.groupName = TarHeader.parseString(bh, offset, TarHeader.USTAR_GROUP_NAMELEN);
    offset += TarHeader.USTAR_GROUP_NAMELEN;
    
    header.devMajor = Int (Octal.parseOctal(bh, offset, TarHeader.USTAR_DEVLEN))
    offset += TarHeader.USTAR_DEVLEN;
    
    header.devMinor = Int (Octal.parseOctal(bh, offset, TarHeader.USTAR_DEVLEN))
    offset += TarHeader.USTAR_DEVLEN;
    
    header.namePrefix = TarHeader.parseString(bh, offset, TarHeader.USTAR_FILENAME_PREFIX);
  }
}
