//version 1.0 (20050213)
//by thakis

#include <cstdio>
#include <cstdlib>
#include <string>
#include <direct.h>
#include <iostream>
using namespace std;

typedef char c8;
typedef c8 Type[4];

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

int min(int a, int b)
{
  return a < b?a:b;
}

int max(int a, int b)
{
  return a > b?a:b;
}

#pragma pack(push, 1)

struct RarcHeader
{
  char type[4]; //'RARC'
  u32 size; //size of the file
  u32 unknown;
  u32 dataStartOffset; //where does the actual data start?
  u32 unknown2[4];
  
  u32 numNodes;
  u32 unknown3[2];
  u32 fileEntriesOffset;
  u32 unknown4;
  u32 stringTableOffset; //where is the string table stored?
  u32 unknown5[2];
};

struct Node
{
  char type[4];
  u32 filenameOffset; //directory name, offset into string table
  u16 unknown;
  u16 numFileEntries; //how many files belong to this node?
  u32 firstFileEntryOffset;
};

struct FileEntry
{
  u16 id; //file id. If this is 0xFFFF, then this entry is a subdirectory link
  u16 unknown;
  u16 unknown2;
  u16 filenameOffset; //file/subdir name, offset into string table
  u32 dataOffset; //offset to file data (for subdirs: index of Node representing the subdir)
  u32 dataSize; //size of data
  u32 zero; //seems to be always '0'
};


#pragma pack(pop)

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

string getString(int pos, FILE* f)
{
  int t = ftell(f);
  fseek(f, pos, SEEK_SET);

  string ret;
  char c;
  while((c = fgetc(f)) != '\0')
    ret.append(1, c);

  fseek(f, t, SEEK_SET);

  return ret;
}

Node getNode(int i, FILE* f)
{
  fseek(f, sizeof(RarcHeader) + i*sizeof(Node), SEEK_SET);
  Node ret;
  fread(&ret, 1, sizeof(Node), f);

  toDWORD(ret.filenameOffset);
  toWORD(ret.unknown);
  toWORD(ret.numFileEntries);
  toDWORD(ret.firstFileEntryOffset);

  return ret;
}

FileEntry getFileEntry(int i, const RarcHeader& h, FILE* f)
{
  fseek(f, h.fileEntriesOffset + i*sizeof(FileEntry) + 0x20, SEEK_SET);
  FileEntry ret;
  fread(&ret, 1, sizeof(FileEntry), f);

  toWORD(ret.id);
  toWORD(ret.unknown);
  toWORD(ret.unknown2);
  toWORD(ret.filenameOffset);
  toDWORD(ret.dataOffset);
  toDWORD(ret.dataSize);
  toDWORD(ret.zero);

  return ret;
}

void dumpNode(const Node& n, const RarcHeader& h, FILE* f)
{
  string nodeName = getString(n.filenameOffset + h.stringTableOffset + 0x20, f);
  _mkdir(nodeName.c_str());
  _chdir(nodeName.c_str());

  for(int i = 0; i < n.numFileEntries; ++i)
  {
    FileEntry curr = getFileEntry(n.firstFileEntryOffset + i, h, f);

    if(curr.id == 0xFFFF) //subdirectory
    {
      if(curr.filenameOffset != 0 && curr.filenameOffset != 2) //don't go to "." and ".."
        dumpNode(getNode(curr.dataOffset, f), h, f);
    }
    else //file
    {
      string currName = getString(curr.filenameOffset + h.stringTableOffset + 0x20, f);
      cout << nodeName << "/" << currName << endl;
      FILE* dest = fopen(currName.c_str(), "wb");

      u32 read = 0;
      u8 buff[1024];
      fseek(f, curr.dataOffset + h.dataStartOffset + 0x20, SEEK_SET);
      while(read < curr.dataSize)
      {
        int r = fread(buff, 1, min(1024, curr.dataSize - read), f);
        fwrite(buff, 1, r, dest);
        read += r;
      }
      fclose(dest);
    }
  }

  _chdir("..");
}

void readFile(FILE* f)
{
  //read header
  RarcHeader h;
  fread(&h, 1, sizeof(h), f);
  toDWORD(h.size);
  toDWORD(h.unknown);
  toDWORD(h.dataStartOffset);
  for(int i = 0; i < 4; ++i)
    toDWORD(h.unknown2[i]);

  toDWORD(h.numNodes);
  toDWORD(h.unknown3[0]);
  toDWORD(h.unknown3[1]);
  toDWORD(h.fileEntriesOffset);
  toDWORD(h.unknown4);
  toDWORD(h.stringTableOffset);
  toDWORD(h.unknown5[0]);
  toDWORD(h.unknown5[1]);

  Node root = getNode(0, f);

  dumpNode(root, h, f);
};

int main(int argc, char* argv[])
{
  FILE* f;
  if(argc < 2 || (f = fopen(argv[1], "rb")) == NULL)
    return EXIT_FAILURE;

  string dirName = argv[1] + string("_dir");
  _mkdir(dirName.c_str());
  _chdir(dirName.c_str());

  readFile(f);

  _chdir("..");
  fclose(f);

  return EXIT_SUCCESS;
}
