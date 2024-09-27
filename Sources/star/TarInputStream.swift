/**
 * Copyright 2012 Kamran Zafar 
 * 
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
open class TarInputStream : java.io.FilterInputStream {
  
  private let SKIP_BUFFER_SIZE = 2048
  private var currentEntry : TarEntry?
  private var currentFileSize : Int64
  private var bytesRead : Int64
  private var defaultSkip = false
  
  public init(_ inputStream : java.io.InputStream ) {
    currentFileSize = 0;
    bytesRead = 0;
    super.init(inputStream);
  }
  
  open func markSupported() -> Bool{
    return false;
  }
  
  /**
   * Not supported
   *
   */
  open func mark(_ readlimit : Int) {
  }
  
  /**
   * Not supported
   *
   */
  open func reset() throws  {
    throw java.io.Throwable.IOException("mark/reset not supported");
  }
  
  /**
   * Read a byte
   *
   * @see java.io.FilterInputStream#read()
   */
  open override func read() throws -> Int {
    var buf : [UInt8] = [0]
    
    let res : Int = try self.read(&buf, 0, 1);
    
    if (res != -1) {
      return 0xFF & Int(buf[0])
    }
    
    return res;
  }
  
  /**
   * Checks if the bytes being read exceed the entry size and adjusts the byte
   * array length. Updates the byte counters
   *
   *
   * @see java.io.FilterInputStream#read(byte[], int, int)
   */
  open override func read(_ b : inout [UInt8], _ off : Int, _ length : Int) throws -> Int {
    var len : Int = length;
    if (currentEntry != nil) {
      if (currentFileSize == currentEntry!.getSize()) {
        return -1;
      } else if ((currentEntry!.getSize() - currentFileSize) < len) {
        len = Int (currentEntry!.getSize() - currentFileSize)
      }
    }
    
    let br : Int = try super.read(&b, off, len);
    
    if (br != -1) {
      if (currentEntry != nil) {
        currentFileSize += Int64(br);
      }
      
      bytesRead += Int64(br);
    }
    
    return br;
  }
  
  /**
   * Returns the next entry in the tar file
   *
   * @return TarEntry
   * @throws IOException
   */
  open func getNextEntry() throws -> TarEntry? {
    try closeCurrentEntry();
    
    var header : [UInt8] = Array(repeating: 0, count: TarConstants.HEADER_BLOCK)
    var theader : [UInt8] = Array(repeating: 0, count: TarConstants.HEADER_BLOCK)
    var tr = 0;
    
    // Read full header
    while (tr < TarConstants.HEADER_BLOCK) {
      let res = try read(&theader, 0, TarConstants.HEADER_BLOCK - tr);
      
      if (res < 0) {
        break;
      }
      
      System.arraycopy(theader, 0, &header, tr, res);
      tr += res;
    }
    
    // Check if record is null
    var eof = true;
    for b in header {
      if (b != 0) {
        eof = false;
        break;
      }
    }
    
    if (!eof) {
      currentEntry = TarEntry(header);
    }
    
    return currentEntry
  }
  
  /**
   * Returns the current offset (in bytes) from the beginning of the stream.
   * This can be used to find out at which point in a tar file an entry's content begins, for instance.
   */
  open func getCurrentOffset() -> Int64{
    return bytesRead;
  }
  
  /**
   * Closes the current tar entry
   *
   * @throws IOException
   */
  open func closeCurrentEntry() throws {
    if (currentEntry != nil) {
      if (currentEntry!.getSize() > currentFileSize) {
        // Not fully read, skip rest of the bytes
        var bs : Int64 = 0;
        while (bs < currentEntry!.getSize() - currentFileSize) {
          let res : Int64 = try skip(currentEntry!.getSize() - currentFileSize - bs);
          
          if (res == 0 && currentEntry!.getSize() - currentFileSize > 0) {
            // I suspect file corruption
            throw java.io.Throwable.IOException("Possible tar file corruption");
          }
          
          bs += res;
        }
      }
      
      currentEntry = nil;
      currentFileSize = 0;
      try skipPad();
    }
  }
  
  /**
   * Skips the pad at the end of each tar entry file content
   *
   * @throws IOException
   */
  public func skipPad() throws {
    if (bytesRead > 0) {
      let extra : Int = Int (bytesRead % Int64(TarConstants.DATA_BLOCK))
      
      if (extra > 0) {
        var bs : Int64 = 0;
        while (bs < TarConstants.DATA_BLOCK - extra) {
          let res  :Int64 = try skip(Int64(TarConstants.DATA_BLOCK) - Int64(extra) - bs);
          bs += res;
        }
      }
    }
  }
  
  /**
   * Skips 'n' bytes on the InputStream<br>
   * Overrides default implementation of skip
   *
   */
  open func skip(_ n : Int64) throws -> Int64 {
    if (defaultSkip) {
      // use skip method of parent stream
      // may not work if skip not implemented by parent
      let bs : Int64 = Int64(try super.skip(Int(n)));
      bytesRead += bs;
      
      return bs;
    }
    
    if (n <= 0) {
      return 0;
    }
    
    var left : Int64 = n;
    var sBuff : [UInt8] = Array(repeating: 0, count: SKIP_BUFFER_SIZE)
    
    while (left > 0) {
      let count = min(left, Int64(SKIP_BUFFER_SIZE))
      let res : Int = try read(&sBuff, 0, Int(count))
      if (res < 0) {
        break;
      }
      left -= Int64(res)
    }
    
    return n - left;
  }
  
  open func isDefaultSkip() -> Bool{
    return defaultSkip;
  }
  
  open func setDefaultSkip(_ defaultSkip : Bool) {
    self.defaultSkip = defaultSkip;
  }
}
