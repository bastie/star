/**
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
open class TarOutputStream : java.io.OutputStream {
  private let out : java.io.OutputStream
  private var bytesWritten : Int64
  private var currentFileSize : Int64
  private var currentEntry : TarEntry?
  
  public init(_ newOut : java.io.OutputStream) {
    self.out = newOut;
    bytesWritten = 0;
    currentFileSize = 0;
  }
  
  public init(_ fout : java.io.File) throws {
    self.out = java.io.BufferedOutputStream(try java.io.FileOutputStream(fout));
    bytesWritten = 0;
    currentFileSize = 0;
  }
  
  /**
   * Opens a file for writing.
   */
  public init(_ fout : java.io.File, _ append : Bool) throws {
    bytesWritten = 0;
    currentFileSize = 0;
    let raf = try java.io.RandomAccessFile(fout, "rw");
    let fileSize : Int64 = fout.length();
    if (append && fileSize > TarConstants.EOF_BLOCK) {
      try raf.seek(fileSize - Int64(TarConstants.EOF_BLOCK))
    }
    out = java.io.BufferedOutputStream(try java.io.FileOutputStream(try raf.getFD()));
  }
  
  /**
   * Appends the EOF record and closes the stream
   *
   * @see java.io.FilterOutputStream#close()
   */
  open override func close() throws {
    try closeCurrentEntry()
    let eof_block : [UInt8] = Array(repeating: 0, count: TarConstants.EOF_BLOCK)
    try write( eof_block )
    try out.close()
  }
  /**
   * Writes a byte to the stream and updates byte counters
   *
   * @see java.io.FilterOutputStream#write(int)
   */
  open override func write(_ b : Int) throws {
    try out.write( b );
    bytesWritten += 1;
    
    if (currentEntry != nil) {
      currentFileSize += 1;
    }
  }
  
  /**
   * Checks if the bytes being written exceed the current entry size.
   *
   * @see java.io.FilterOutputStream#write(byte[], int, int)
   */
  
  open override func write(_ b : [UInt8], _ off : Int, _ len : Int) throws {
    if (currentEntry != nil && !(currentEntry!.isDirectory())) {
      if (currentEntry!.getSize() < currentFileSize + Int64(len)) {
        throw java.io.Throwable.IOException( "The current entry[\(currentEntry!.getName())] size[\(currentEntry!.getSize())] is smaller than the bytes[\(( currentFileSize + Int64(len) ))] being written." );
      }
    }
    
    try out.write( b, off, len );
    
    bytesWritten += Int64(len)
    
    if (currentEntry != nil) {
      currentFileSize += Int64(len)
    }
  }
  
  /**
   * Writes the next tar entry header on the stream
   *
   * @throws IOException
   */
  open func putNextEntry(_ entry : TarEntry) throws {
    try closeCurrentEntry();
    var header : [UInt8] = Array(repeating: 0, count: TarConstants.HEADER_BLOCK)
    entry.writeEntryHeader( &header );
    
    try write( header );
    
    currentEntry = entry;
  }
  
  /**
   * Closes the current tar entry
   *
   * @throws IOException
   */
  open func closeCurrentEntry() throws  {
    if let currentEntry = self.currentEntry {
      if (currentEntry.getSize() > currentFileSize) {
        throw java.io.Throwable.IOException( "The current entry[\(currentEntry.getName())] of size[\(currentEntry.getSize())] has not been fully written." )
      }
      
      self.currentEntry = nil;
      currentFileSize = 0;
      
      try pad();
    }
  }
  
  /**
   * Pads the last content block
   *
   * @throws IOException
   */
  open func pad() throws {
    if (bytesWritten > 0) {
      let extra : Int = Int ( bytesWritten % Int64(TarConstants.DATA_BLOCK) )
      
      if (extra > 0) {
        let extraBytes : [UInt8] = Array(repeating: 0, count: TarConstants.DATA_BLOCK - extra)
        try write( extraBytes );
      }
    }
  }
}
