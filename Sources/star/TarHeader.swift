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
import Foundation

/**
 * Header
 * 
 * <pre>
 * Offset  Size     Field
 * 0       100      File name
 * 100     8        File mode
 * 108     8        Owner's numeric user ID
 * 116     8        Group's numeric user ID
 * 124     12       File size in bytes
 * 136     12       Last modification time in numeric Unix time format
 * 148     8        Checksum for header block
 * 156     1        Link indicator (file type)
 * 157     100      Name of linked file
 * </pre>
 * 
 * 
 * File Types
 * 
 * <pre>
 * Value        Meaning
 * '0'          Normal file
 * (ASCII NUL)  Normal file (now obsolete)
 * '1'          Hard link
 * '2'          Symbolic link
 * '3'          Character special
 * '4'          Block special
 * '5'          Directory
 * '6'          FIFO
 * '7'          Contigous
 * </pre>
 * 
 * 
 * 
 * GNU Ustar header
 * 
 * <pre>
 * Offset  Size    Field
 * 257     8       UStar indicator "ustar  "
 * 265     32      Owner user name
 * 297     32      Owner group name
 * 329     8       Device major number
 * 337     8       Device minor number
 * 345     155     Filename prefix
 * </pre>
 */

public class TarHeader {
  
  /*
   * Header
   */
  public static let NAMELEN = 100;
  public static let MODELEN = 8;
  public static let UIDLEN = 8;
  public static let GIDLEN = 8;
  public static let SIZELEN = 12;
  public static let MODTIMELEN = 12;
  public static let CHKSUMLEN = 8;
  public static let LF_OLDNORM : UInt8 = 0;
  
  /*
   * File Types
   */
  public static let LF_NORMAL : UInt8 = 48 // (byte) '0';
  public static let LF_LINK : UInt8 = 49 // (byte) '1';
  public static let LF_SYMLINK : UInt8 = 50 // (byte) '2';
  public static let LF_CHR : UInt8 = 51 //(byte) '3';
  public static let LF_BLK : UInt8 = 52// (byte) '4';
  public static let LF_DIR : UInt8 = 53 // (byte) '5';
  public static let LF_FIFO : UInt8 = 54 //(byte) '6';
  public static let LF_CONTIG : UInt8 = 55 // (byte) '7';
  
  /*
   * GNU header
   */
  
  public static let USTAR_MAGIC = "ustar  "
  
  public static let USTAR_MAGICLEN = 8
  public static let USTAR_USER_NAMELEN = 32
  public static let USTAR_GROUP_NAMELEN = 32
  public static let USTAR_DEVLEN = 8
  public static let USTAR_FILENAME_PREFIX = 155
  
  // Header values
  public var name : java.lang.StringBuilder
  public var mode : Int = 0
  public var userId : Int
  public var groupId : Int
  public var size : Int64 = 0
  public var modTime : Int64 = 0
  public var checkSum : Int = 0
  public var typeflag : UInt8 = 0
  public var linkName : java.lang.StringBuilder
  public var magic : java.lang.StringBuilder
  public var userName : java.lang.StringBuilder
  public var groupName : java.lang.StringBuilder
  public var devMajor : Int = 0
  public var devMinor : Int = 0
  public var namePrefix : java.lang.StringBuilder
  
  public init() {
    self.magic = StringBuilder(TarHeader.USTAR_MAGIC);
    
    self.name = StringBuilder();
    self.linkName = StringBuilder();
    
    self.userId = 0;
    self.groupId = 0;
    self.userName = StringBuilder();
    self.groupName = StringBuilder();
    self.namePrefix = StringBuilder();
  }
  
  /**
   * Parse an entry name from a header buffer.
   *
   * @param header
   *            The header buffer from which to parse.
   * @param offset
   *            The offset into the buffer from which to parse.
   * @param length
   *            The number of header bytes to parse.
   * @return The header's entry name.
   */
  public static func parseString(_ header : [UInt8], _ offset : Int, _ length : Int) -> StringBuilder {
    var count = 0;
    
    let byteBuffer = try! java.nio.ByteBuffer.allocate(length);
    
    let end = offset + length;
    for i in offset..<end {
      if (header[i] == 0) {
        break;
      }
      count += 1
      let _ = try! byteBuffer.put(header[i]);
    }
    
    let asData : Data = byteBuffer.array()[0..<count]
    let result = StringBuilder(String(data: asData, encoding: .utf8)!)
    
    return result
  }
  
  /**
   * Write string as bytes into buffer.
   *
   * @param entry
   *            The string buffer from which to parse.
   * @param offset
   *            The offset into the buffer from which to parse.
   * @param length
   *            The number of header bytes to parse.
   * @return The new offset after writing the entry.
   */
  public static func getStringBytes(_ entry : StringBuilder, _ _buf : [UInt8], _ offset : Int, _ length : Int) -> Int {
    var buf = _buf
    let bytes : [UInt8] = [UInt8] (entry.toString().data(using: .utf8)!)
    //var i : Int = 0
    
    /* for (i = 0; i < length && i < bytes.length; ++i) {
     buf[offset + i] = bytes[i];
     }
     */
    for i in 0..<min(length, bytes.count) {
      buf[offset + i] = bytes[i]
    }
    
    /* for (; i < length; ++i) {
     buf[offset + i] = 0;
     }
     */
    for i in min(length, bytes.count)..<length {
      buf[offset + i] = 0
    }
    
    
    
    return offset + length;
  }
  
  /**
   * Creates a new header for a file/directory entry.
   *
   *
   * @param entryName
   *            File name
   * @param size
   *            File size in bytes
   * @param modTime
   *            Last modification time in numeric Unix time format
   * @param dir
   *            Is directory
   */
  public static func createHeader(_ entryName : String, _ size : long, _ modTime : long, _ dir : Bool, _ permissions : Int) -> TarHeader{
    var name = entryName;
    name = TarUtils.trim(name.replace(java.io.File.separatorChar, "/"), "/")
    
    let header = TarHeader()
    header.linkName = StringBuilder()
    header.mode = permissions
    
    if (name.count > 100) {
      header.namePrefix = StringBuilder(name.substring(0, name.lastIndexOf("/")));
      header.name = StringBuilder(name.substring(name.lastIndexOf("/") + 1));
    } else {
      header.name = StringBuilder(name);
    }
    if (dir) {
      header.typeflag = TarHeader.LF_DIR;
      if (try! header.name.charAt(header.name.length() - 1) != "/") {
        _ = header.name.append("/")
      }
      header.size = 0;
    } else {
      header.typeflag = TarHeader.LF_NORMAL
      header.size = size
    }
    
    header.modTime = modTime
    header.checkSum = 0
    header.devMajor = 0
    header.devMinor = 0
    
    return header
  }
}
