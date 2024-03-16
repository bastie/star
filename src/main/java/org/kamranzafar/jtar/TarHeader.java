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

package org.kamranzafar.jtar;

import java.io.File;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;

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
    public static final int NAMELEN = 100;
    public static final int MODELEN = 8;
    public static final int UIDLEN = 8;
    public static final int GIDLEN = 8;
    public static final int SIZELEN = 12;
    public static final int MODTIMELEN = 12;
    public static final int CHKSUMLEN = 8;
    public static final byte LF_OLDNORM = 0;

    /*
     * File Types
     */
    public static final byte LF_NORMAL = (byte) '0';
    public static final byte LF_LINK = (byte) '1';
    public static final byte LF_SYMLINK = (byte) '2';
    public static final byte LF_CHR = (byte) '3';
    public static final byte LF_BLK = (byte) '4';
    public static final byte LF_DIR = (byte) '5';
    public static final byte LF_FIFO = (byte) '6';
    public static final byte LF_CONTIG = (byte) '7';

    /*
     * GNU header
     */

    public static final String USTAR_MAGIC = "ustar  ";

    public static final int USTAR_MAGICLEN = 8;
    public static final int USTAR_USER_NAMELEN = 32;
    public static final int USTAR_GROUP_NAMELEN = 32;
    public static final int USTAR_DEVLEN = 8;
    public static final int USTAR_FILENAME_PREFIX = 155;

    // Header values
    public StringBuilder name;
    public int mode;
    public int userId;
    public int groupId;
    public long size;
    public long modTime;
    public int checkSum;
    public byte typeflag;
    public StringBuilder linkName;
    public StringBuilder magic;
    public StringBuilder userName;
    public StringBuilder groupName;
    public int devMajor;
    public int devMinor;
    public StringBuilder namePrefix;

    public TarHeader() {
        this.magic = new StringBuilder(TarHeader.USTAR_MAGIC);

        this.name = new StringBuilder();
        this.linkName = new StringBuilder();

        this.userId = 0;
        this.groupId = 0;
        this.userName = new StringBuilder();
        this.groupName = new StringBuilder();
        this.namePrefix = new StringBuilder();
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
    public static StringBuilder parseString(byte[] header, int offset, int length) {
        int count = 0;

        ByteBuffer byteBuffer = ByteBuffer.allocate(length);

        int end = offset + length;
        for (int i = offset; i < end; ++i) {
            if (header[i] == 0)
                break;
            count++;
            byteBuffer.put(header[i]);
        }

        return new StringBuilder(new String(byteBuffer.array(), 0, count, StandardCharsets.UTF_8));
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
    public static int getStringBytes(StringBuilder entry, byte[] buf, int offset, int length) {
        byte[] bytes = StandardCharsets.UTF_8.encode(entry.toString()).array();
        int i;

        for (i = 0; i < length && i < bytes.length; ++i) {
            buf[offset + i] = bytes[i];
        }

        for (; i < length; ++i) {
            buf[offset + i] = 0;
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
    public static TarHeader createHeader(String entryName, long size, long modTime, boolean dir, int permissions) {
        String name = entryName;
        name = TarUtils.trim(name.replace(File.separatorChar, '/'), '/');

        TarHeader header = new TarHeader();
        header.linkName = new StringBuilder();
        header.mode = permissions;

        if (name.length() > 100) {
            header.namePrefix = new StringBuilder(name.substring(0, name.lastIndexOf('/')));
            header.name = new StringBuilder(name.substring(name.lastIndexOf('/') + 1));
        } else {
            header.name = new StringBuilder(name);
        }
        if (dir) {
            header.typeflag = TarHeader.LF_DIR;
            if (header.name.charAt(header.name.length() - 1) != '/') {
                header.name.append("/");
            }
            header.size = 0;
        } else {
            header.typeflag = TarHeader.LF_NORMAL;
            header.size = size;
        }

        header.modTime = modTime;
        header.checkSum = 0;
        header.devMajor = 0;
        header.devMinor = 0;

        return header;
    }
}
