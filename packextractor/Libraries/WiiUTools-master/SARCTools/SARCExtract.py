#
# Made by NWPlayer123 and MasterVermilli0n/AboodXD, no rights reserved, feel free to do whatever
#

import os
import sys
import struct

from libyaz0 import decompress as Yaz0Dec


def uint8(data, pos, bom):
    return struct.unpack(bom + "B", data[pos:pos + 1])[0]


def uint16(data, pos, bom):
    return struct.unpack(bom + "H", data[pos:pos + 2])[0]


def uint32(data, pos, bom):
    return struct.unpack(bom + "I", data[pos:pos + 4])[0]


def bytes_to_string(data, offset=0, charWidth=1, encoding='utf-8'):
    # Thanks RoadrunnerWMC
    end = data.find(b'\0' * charWidth, offset)
    if end == -1:
        return data[offset:].decode(encoding)

    return data[offset:end].decode(encoding)


def sarc_extract(data, mode):
    print("Reading SARC....")
    pos = 6

    name, ext = os.path.splitext(sys.argv[1])

    if mode == 1:  # Don't need to check again with normal SARC
        magic1 = data[0:4]

        if magic1 != b"SARC":
            print("Not a SARC Archive!")
            print("Writing Decompressed File....")

            with open(name + ".bin", "wb") as f:
                f.write(data)

            print("Done!")

    # Byte Order Mark
    order = uint16(data, pos, ">")
    pos += 6

    if order == 0xFEFF:  # Big Endian
        bom = ">"
    elif order == 0xFFFE:  # Little Endian
        bom = "<"
    else:
        print("Invalid BOM!")
        sys.exit(1)

    # Start of data section
    doff = uint32(data, pos, bom)
    pos += 8

    # ---------------------------------------------------------------

    magic2 = data[pos:pos + 4]
    pos += 6

    assert magic2 == b"SFAT"

    # Node Count
    node_count = uint16(data, pos, bom)
    pos += 6

    nodes = []

    print("Reading File Attribute Table...")

    for x in range(node_count):
        pos += 8

        # File Offset Start
        srt = uint32(data, pos, bom)
        pos += 4

        # File Offset End
        end = uint32(data, pos, bom)
        pos += 4

        nodes.append([srt, end])

    # ---------------------------------------------------------------
    magic3 = data[pos:pos + 4]
    pos += 8

    assert magic3 == b"SFNT"
    strings = []

    print("Reading file names....")
    no_names = 0

    if bytes_to_string(data[pos:]) == "":
        print("No file names found....")
        no_names = 1

        for x in range(node_count):
            strings.append("file" + str(x))

    else:
        for x in range(node_count):
            string = bytes_to_string(data[pos:])
            pos += len(string)

            while (data[pos]) == 0:
                pos += 1  # Move to the next string

            strings.append(string)

    # ---------------------------------------------------------------
    print("Writing Files....")

    try:
        os.mkdir(name)
    except OSError:
        print("Folder already exists, continuing....")

    if no_names:
        print("No names found. Trying to guess the file names...")

    bntx_count = 0
    bnsh_count = 0
    flan_count = 0
    flyt_count = 0
    flim_count = 0
    gtx_count  = 0
    sarc_count = 0
    szs_count  = 0
    file_count = 0

    for x in range(node_count):
        filename = os.path.join(name, strings[x])

        if not os.path.exists(os.path.dirname(filename)):
            os.makedirs(os.path.dirname(filename))

        start, end = (doff + nodes[x][0]), (doff + nodes[x][1])
        filedata = data[start:end]

        if no_names:
            if filedata[0:4] == b"BNTX":
                filename = name + "/" + "bntx" + str(bntx_count) + ".bntx"
                bntx_count += 1

            elif filedata[0:4] == b"BNSH":
                filename = name + "/" + "bnsh" + str(bnsh_count) + ".bnsh"
                bnsh_count += 1

            elif filedata[0:4] == b"FLAN":
                filename = name + "/" + "bflan" + str(flan_count) + ".bflan"
                flan_count += 1

            elif filedata[0:4] == b"FLYT":
                filename = name + "/" + "bflyt" + str(flyt_count) + ".bflyt"
                flyt_count += 1

            elif filedata[-0x28:-0x24] == b"FLIM":
                filename = name + "/" + "bflim" + str(flim_count) + ".bflim"
                flim_count += 1

            elif filedata[0:4] == b"Gfx2":
                filename = name + "/" + "gtx" + str(gtx_count) + ".gtx"
                gtx_count += 1

            elif filedata[0:4] == b"SARC":
                filename = name + "/" + "sarc" + str(sarc_count) + ".sarc"
                sarc_count += 1

            elif filedata[0:4] == b"Yaz0":
                filename = name + "/" + "szs" + str(szs_count) + ".szs"
                szs_count += 1

            else:
                filename = name + "/" + "file" + str(file_count)
                file_count += 1

        print(filename)

        with open(filename, "wb") as f:
            f.write(filedata)

    print("Done!")


def main():
    print("SARCExtract v0.5 by MasterVermilli0n/AboodXD")
    print("Originally by NWPlayer123")

    if len(sys.argv) != 2:
        print("Usage: SARCExtract archive.szs")
        sys.exit(1)

    with open(sys.argv[1], "rb") as f:
        data = f.read()

    magic = data[0:4]

    if magic == b"Yaz0":
        decompressed = Yaz0Dec(data)
        sarc_extract(decompressed, 1)

    elif magic == b"SARC":
        sarc_extract(data, 0)

    else:
        print("Unknown File Format: First 4 bytes of file must be Yaz0 or SARC")
        sys.exit(1)

if __name__ == "__main__":
    main()
