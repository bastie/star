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
 * @author Kamran
 * 
 */
public class TarUtils {
  /**
   * Determines the tar file size of the given folder/file path
   */
  public static func calculateTarSize(_ path : java.io.File) -> long {
    return tarSize(path) + Int64(TarConstants.EOF_BLOCK);
  }
  
  private static func tarSize(_ dir : java.io.File) -> long{
    var size : Int64 = 0;
    
    if (dir.isFile()) {
      return entrySize(dir.length());
    } else {
      let subFiles : [java.io.File]? = dir.listFiles();
      if let subFiles {
        if (subFiles.length > 0) {
          for file in subFiles {
            if (file.isFile()) {
              size += entrySize(file.length());
            } else {
              size += tarSize(file);
            }
          }
        } else {
          // Empty folder header
          return long(TarConstants.HEADER_BLOCK);
        }
      }
    }
    
    return size;
  }
  
  private static func entrySize(_ fileSize : long) -> long {
    var size : long = 0;
    size += Int64(TarConstants.HEADER_BLOCK); // Header
    size += fileSize; // File size
    
    let extra : long = size % Int64(TarConstants.DATA_BLOCK);
    
    if (extra > 0) {
      size += (Int64(TarConstants.DATA_BLOCK) - extra); // pad
    }
    
    return size;
  }
  
  public static func trim(_ s : String, _ c : Character) -> String{
    var tmp = java.lang.StringBuilder(s)
    for i in 0..<tmp.count {
      if (try! tmp.charAt(i) != c) {
        break;
      } else {
        try! tmp = tmp.deleteCharAt(i);
      }
    }
    
    for i in (0..<tmp.count).reversed() {//for (int i = tmp.length() - 1; i >= 0; i--) {
      if (try! tmp.charAt(i) != c) {
        break;
      } else {
        try! tmp = tmp.deleteCharAt(i);
      }
    }
    return tmp.toString();
    
  }
}
