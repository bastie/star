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
 * @author Kamran Zafar, John Wu
 * 
 */
open class Octal {
  
  // 8 ^ 11 - 1
  private static let OCTAL_MAX : Int64 = 8589934591
  private static let LARGE_NUM_MASK : UInt8 = UInt8 (0x80)
  
  /**
   * Parse an octal string from a header buffer.
   *
   * @param header
   *            The header buffer from which to parse.
   * @param offset
   *            The offset into the buffer from which to parse.
   * @param length
   *            The number of header bytes to parse.
   *
   * @return The long value of the octal string.
   */
  public static func parseOctal(_ header : [UInt8], _ offset : Int, _ length : Int) -> Int64 {
    var result : Int64 = 0;
    var stillPadding = true;
    
    let end : Int = offset + length;
    for i in offset..<end {
      let b : UInt8 = header[i];
      
      if ((b & LARGE_NUM_MASK) != 0 && length == 12) {
        // Read the lower 8 bytes as big-endian long value
        // java: return java.nio.ByteBuffer.wrap(header, offset + 4, 8).order(java.nio.ByteOrder.BIG_ENDIAN).getLong();

        // Extrahiere die 8 Bytes ab dem Offset
        let bytes = header[offset..<offset+8]
        
        // Konvertiere die Bytes in einen Int64 im Big-Endian-Format
        var value: Int64 = 0
        for byte in bytes.reversed() {
          value <<= 8
          value |= Int64(byte)
        }
        
        return value
        
      }
      
      if (b == 0) {
        break;
      }
      
      if (b == Character(" ").asciiValue! || b == Character("0").asciiValue!) {
        if (stillPadding) {
          continue;
        }
        
        if (b == Character(" ").asciiValue!) {
          break;
        }
      }
      
      stillPadding = false;
      
      result = ( result << 3 ) + Int64(( b - Character("0").asciiValue! ));
    }
    
    return result;
  }
  
  /**
   * Write an octal integer to a header buffer.
   *
   * @param value
   *            The value to write.
   * @param buf
   *            The header buffer from which to parse.
   * @param offset
   *            The offset into the buffer from which to parse.
   * @param length
   *            The number of header bytes to parse.
   *
   * @return The new offset.
   */
  public static func getOctalBytes(_ value : Int64, _ buf : inout [UInt8], _ offset : Int, _ length : Int) -> Int {
    if (value > OCTAL_MAX && length == 12) {
      buf[offset] = LARGE_NUM_MASK;
      buf[offset + 1] = 0;
      buf[offset + 2] = 0;
      buf[offset + 3] = 0;
      // Java: java.nio.ByteBuffer.wrap(buf, offset + 4, 8).order(java.nio.ByteOrder.BIG_ENDIAN).putLong(value);
      var value = value
      for i in (0..<8).reversed() {
        buf[offset + i] = UInt8(truncatingIfNeeded: value & 0xFF)
        value >>= 8
      }
      return offset + length;
    }
    
    var idx : Int = length - 1
    
    buf[offset + idx] = 0
    idx -= 1
    
    var val = value
    while idx >= 0 {
      //for (long val = value; idx >= 0; --idx) {
      buf[offset + idx] = (UInt8(Character("0").asciiValue!) + UInt8 (val & 7))
      val = val >> 3
      
      idx -= 1
    }
    
    return offset + length;
  }
  
  /**
   * Write the checksum octal integer to a header buffer.
   *
   * @param value
   *            The value to write.
   * @param buf
   *            The header buffer from which to parse.
   * @param offset
   *            The offset into the buffer from which to parse.
   * @param length
   *            The number of header bytes to parse.
   * @return The new offset.
   */
  public static func getCheckSumOctalBytes(_ value : Int64, _ buf : inout [UInt8], _ offset : Int, _ length : Int) -> Int {
    _ = getOctalBytes(value, &buf, offset, length - 1);
    buf[offset + length - 1] = UInt8(Character(" ").asciiValue!)
    return offset + length;
  }
  
}
