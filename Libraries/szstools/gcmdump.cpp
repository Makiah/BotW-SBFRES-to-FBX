//version 1.0 (20050213)
//by thakis

#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <vector>
#include <string>
#include <iterator>
#include <stack>
#include <direct.h>
using namespace std;

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef char c8;

typedef FILE* GcmFile;

int min(int a, int b)
{ return a<b?a:b; }

void toWORD(u16& w)
{
  u8 w1 = w & 0xFF;
  u8 w2 = w >> 8;
  w = (w1 << 8) | w2;
}

void toDWORD(u32& d)
{
  u8 w1 = d & 0xFF;
  u8 w2 = (d >> 8) & 0xFF;
  u8 w3 = (d >> 16) & 0xFF;
  u8 w4 = d >> 24;
  d = (w1 << 24) | (w2 << 16) | (w3 << 8) | w4;
}

#pragma pack(push, 1)

struct GameCode
{
  u8 consoleId;
  union
  {
    u16 gameCode;
    u8 gameCodeArr[2];
  };
  u8 countryCode;
  union
  {
    u16 makerCode;
    c8 makerCodeArr[2];
  };
};

struct DiskHeader
{
  GameCode gameCode;
  u8 diskId, version, audioStreaming, streamBufferSize;
  u8 unused[0x12];
  union
  {
    u32 dvdMagicWord;
    c8 dvdMagicWordArr[4];
  };
  c8 gameName[0x3e0];
  u32 debugMonitorOffset;
  u32 debugLoadAddress;
  u8 unused2[0x18];
  u32 dolOffset;
  u32 fstOffset;
  u32 fstSize;
  u32 fstMaximumSize;
  u32 userPosition;
  u32 userLength;
  u32 unknown;
  u32 unused3;
};

struct FileEntry
{
  u8 isDirectory; //0: file, 1: dir
  u32 fileNameOffset; //this is only 3 bytes on the disk :-(
  union
  {
    u32 fileOffset;  //file
    u32 parentOffset; //dir
  };
  union
  {
    u32 numEntries; //for root entry
    u32 fileLength; //file
    u32 nextOffset; //dir
  };

  string name;
};

struct FileEntryImpl //this is how it's stored on-disk
{
  u8 isDirectory;
  u8 fileNameOffset[3]; //sadly, this is a 3-byte number...
  u32 fileOffset;
  u32 nextOffset;
};

struct FileSystemTable
{
  vector<FileEntry> entries;
  //vector<string> fileNames;
};

#pragma pack(pop)

GcmFile openGcm(const char* fileName)
{
  return fopen(fileName, "rb");
}

int closeGcm(GcmFile file)
{
  return fclose(file);
}

int readDiskHeader(GcmFile f, DiskHeader& header)
{
  fseek(f, 0, SEEK_SET);
  size_t ret = fread(&header, sizeof(DiskHeader), 1, f);

  toDWORD(header.dvdMagicWord);
  toDWORD(header.debugMonitorOffset);
  toDWORD(header.debugLoadAddress);
  toDWORD(header.dolOffset);
  toDWORD(header.fstOffset);
  toDWORD(header.fstSize);
  toDWORD(header.fstMaximumSize);
  toDWORD(header.userPosition);
  toDWORD(header.userLength);
  toDWORD(header.unknown);
  toDWORD(header.unused3);

  return ret;
}

int readEntry(GcmFile f, FileEntry& entry)
{
  FileEntryImpl feImpl;

  fread(&feImpl, sizeof(FileEntryImpl), 1, f);

  toDWORD(feImpl.fileOffset);
  toDWORD(feImpl.nextOffset);

  entry.isDirectory = feImpl.isDirectory;
  entry.fileNameOffset = 
    (feImpl.fileNameOffset[0] << 16) |
    (feImpl.fileNameOffset[1] << 8) |
     feImpl.fileNameOffset[2];
  entry.fileOffset = feImpl.fileOffset;
  entry.nextOffset = feImpl.nextOffset;

  return 1;
}

int readFST(GcmFile f, const DiskHeader& header, FileSystemTable& fst)
{
  fseek(f, header.fstOffset, SEEK_SET);

  //read files
  int numFiles = 1;
  for(int i = 0; i < numFiles; ++i)
  {
    FileEntry entry;
    readEntry(f, entry);
    fst.entries.push_back(entry);
    if(i == 0)
      numFiles = entry.numEntries;
  }

  //read filename table
  /*
  u32 readBytes = sizeof(FileEntryImpl)*fst.entries.size();
  while(readBytes < header.fstSize)
  {
    string currString;
    char c;
    ++readBytes; //0 char
    while((c = fgetc(f)) != '\0' && readBytes < header.fstSize)
    {
      ++readBytes; currString.append(1, c);
    }
    fst.fileNames.push_back(currString);
  }
  //*/

  int fileTableOffset = sizeof(FileEntryImpl)*fst.entries.size();
  for(int j = 0; j < fst.entries.size(); ++j)
  {
    fseek(f, header.fstOffset + fileTableOffset + fst.entries[j].fileNameOffset, SEEK_SET);
    int readBytes = fileTableOffset + fst.entries[j].fileNameOffset;

    char c;
    ++readBytes; //0 char
    while((c = fgetc(f)) != '\0' && readBytes < header.fstSize)
    {
      ++readBytes; fst.entries[j].name.append(1, c);
    }
  }

  return 1;
}

int main(int argc, char* argv[])
{
  if(argc < 2)
    return EXIT_FAILURE;

  DiskHeader header;
  FileSystemTable fst;
  GcmFile f = openGcm(argv[1]);
  if(f == NULL)
    return EXIT_FAILURE;

  readDiskHeader(f, header);
  readFST(f, header, fst);

  //copy file system to harddisk

  //for now, dump directory structure
  //*
  string path;

  cout << fst.entries.size() << " file system entries:" << endl;

  stack<int> directoryEnd;
  directoryEnd.push(fst.entries.size());

  string dirName = argv[1] + string("_dir");
  _mkdir(dirName.c_str());
  _chdir(dirName.c_str());

  for(int i = 1; i < fst.entries.size(); ++i)
  {
    FileEntry& e = fst.entries[i];
    string name;

    while(i >= directoryEnd.top())
    {
      directoryEnd.pop();
      path = path.substr(0, path.rfind('/'));
      _chdir("..");
    }

    if(e.isDirectory)
    {
      directoryEnd.push(e.nextOffset);

      _mkdir(e.name.c_str());
      _chdir(e.name.c_str());

      path = "/" + e.name;
      int off = fst.entries[i].parentOffset;
      while(off != 0)
      {
        path = "/" + fst.entries[off].name + path;
        off = fst.entries[off].parentOffset;
      }
      //cout << path << endl;
      name = path;
    }
    else
    {
      name = path + "/" + e.name;

      FILE* outFile = fopen(e.name.c_str(), "wb");
      u32 read = 0;
      u8 buff[1024];
      fseek(f, e.fileOffset, SEEK_SET);
      while(read < e.fileLength)
      {
        int r = fread(buff, 1, min(1024, e.fileLength - read), f);
        fwrite(buff, 1, r, outFile);
        read += r;
      }
      fclose(outFile);
    }

    cout << name << endl;
  }
  //*/

  closeGcm(f);

  //cout << fst.entries.size() << " filenames" << endl;
  //copy(fst.entries.begin(), fst.fileNames.end(), ostream_iterator<string>(cout, "\n"));

  return EXIT_SUCCESS;
}
