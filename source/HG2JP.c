/* Heavy Gear II Japanese glyph alpha repair. Only 16x16 RGB555 glyph bitmaps
   passed to the simulator's TextOutA import are changed. No global hooks. */
typedef void* HANDLE;
typedef unsigned long DWORD;
typedef long LONG;
typedef unsigned short WORD;
typedef unsigned short wchar_t;
typedef int BOOL;
#define API __stdcall
#define IMPORT __declspec(dllimport)
typedef struct { LONG type,width,height,stride; WORD planes,bpp; void* bits; } BITMAP;
typedef struct { DWORD size; LONG width,height; WORD planes,bpp; DWORD compression,imageSize; LONG xppm,yppm; DWORD colors,important; } INFO;
typedef struct { BITMAP bitmap; INFO info; DWORD masks[3]; HANDLE section; DWORD offset; } SECTION;
typedef struct { DWORD width,height; LONG originX,originY; short advanceX,advanceY; } GLYPHMETRICS;
typedef struct { WORD fraction; short value; } FIXED;
typedef struct { FIXED m11,m12,m21,m22; } MAT2;
IMPORT HANDLE API GetCurrentObject(HANDLE,DWORD);
IMPORT int API GetObjectW(HANDLE,int,void*);
IMPORT BOOL API GdiFlush(void);
IMPORT BOOL API TextOutA(HANDLE,int,int,const char*,int);
IMPORT int API SetBkMode(HANDLE,int);
IMPORT DWORD API SetBkColor(HANDLE,DWORD);
IMPORT DWORD API SetTextColor(HANDLE,DWORD);
IMPORT unsigned int API GetSystemPaletteEntries(HANDLE,unsigned int,unsigned int,void*);
IMPORT int API MultiByteToWideChar(unsigned int,DWORD,const char*,int,wchar_t*,int);
IMPORT HANDLE API CreateFontW(int,int,int,int,int,DWORD,DWORD,DWORD,DWORD,DWORD,DWORD,DWORD,DWORD,const wchar_t*);
IMPORT HANDLE API SelectObject(HANDLE,HANDLE);
IMPORT BOOL API DeleteObject(HANDLE);
IMPORT DWORD API GetGlyphIndicesW(HANDLE,const wchar_t*,int,WORD*,DWORD);
IMPORT DWORD API GetGlyphOutlineW(HANDLE,unsigned int,unsigned int,GLYPHMETRICS*,DWORD,void*,const MAT2*);

DWORD API HG2SetTextColor(HANDLE dc,DWORD color){return SetTextColor(dc,color);}
DWORD API HG2SetBkColor(HANDLE dc,DWORD color){return SetBkColor(dc,color);}
int API HG2SetBkMode(HANDLE dc,int mode){return SetBkMode(dc,mode);}
unsigned int API HG2GetSystemPaletteEntries(HANDLE dc,unsigned int start,unsigned int count,void* entries){return GetSystemPaletteEntries(dc,start,count,entries);}

/* The second call originally draws the same glyph one pixel to the right.
   Replace the pair with a single grid-fitted Japanese glyph. */
static BOOL DrawJapaneseGlyph(HANDLE dc,const BITMAP* bm,const char* text,int count) {
    wchar_t ch;
    if(count!=2 || MultiByteToWideChar(932,8,text,count,&ch,1)!=1) return 0;

    HANDLE font=CreateFontW(-15,0,0,0,400,0,0,0,128,0,0,4,0,L"BIZ UD Gothic");
    if(!font) return 0;
    HANDLE previous=SelectObject(dc,font);
    GLYPHMETRICS glyph;
    const MAT2 identity={{0,1},{0,0},{0,0},{0,1}};
    unsigned char coverage[16*16];
    DWORD bytes=0xffffffff;
    if(previous) {
        WORD index;
        if(GetGlyphIndicesW(dc,&ch,1,&index,1)==1 && index!=0xffff)
            bytes=GetGlyphOutlineW(dc,index,0x86,&glyph,sizeof(coverage),coverage,&identity);
        SelectObject(dc,previous);
    }
    DeleteObject(font);
    if(!bytes || bytes==0xffffffff || !glyph.width || !glyph.height || glyph.width>16 || glyph.height>16)
        return 0;

    int width=(int)glyph.width,height=(int)glyph.height;
    int stride=(width+3)&~3;
    if(bytes<(DWORD)(stride*height)) return 0;
    int left=(16-glyph.advanceX)/2+glyph.originX;
    int top=13-glyph.originY;
    if(left<0) left=0;
    if(top<0) top=0;
    if(left+width>16) left=16-width;
    if(top+height>16) top=16-height;
    GdiFlush();
    for(int row=0;row<16;row++) {
        // DirectDraw exposes this surface in texture row order.
        WORD* pixels=(WORD*)((char*)bm->bits+row*bm->stride);
        for(int col=0;col<16;col++) {
            int gx=col-left,gy=row-top;
            BOOL ink=gx>=0 && gx<width && gy>=0 && gy<height
                && coverage[gy*stride+gx]>=26;
            // Keep the same RGB on transparent texels to avoid a dark fringe
            // when Direct3D filters across the one-bit alpha boundary.
            pixels[col]=ink ? 0xffff : 0x7fff;
        }
    }
    return 1;
}

BOOL API HG2TextOutA(HANDLE dc,int x,int y,const char* text,int count) {
    SECTION ds;
    int got=GetObjectW(GetCurrentObject(dc,7),sizeof(ds),&ds);
    BITMAP* bm=&ds.bitmap;
    if(got!=(int)sizeof(ds) || !bm->bits || bm->width!=16 || bm->height!=16 ||
       bm->bpp!=16 || ds.masks[0]!=0x7c00 || ds.masks[1]!=0x3e0 || ds.masks[2]!=0x1f)
        return TextOutA(dc,x,y,text,count);
    if(x==1 && y==0 && ds.info.height==16 && DrawJapaneseGlyph(dc,bm,text,count))
        return 1;
    GdiFlush();
    if(x==0 && y==0) {
        for(int row=0;row<16;row++) {
            WORD* pixels=(WORD*)((char*)bm->bits+row*bm->stride);
            for(int col=0;col<16;col++) pixels[col]=0;
        }
    }
    int mode=SetBkMode(dc,1);
    DWORD background=SetBkColor(dc,0);
    BOOL result=TextOutA(dc,x,y,text,count);
    GdiFlush();
    if(result) {
        for(int row=0;row<16;row++) {
            WORD* pixels=(WORD*)((char*)bm->bits+row*bm->stride);
            for(int col=0;col<16;col++) {
                WORD rgb=pixels[col]&0x7fff;
                pixels[col]=rgb ? (WORD)(rgb|0x8000) : 0;
            }
        }
    }
    SetBkColor(dc,background);
    SetBkMode(dc,mode);
    return result;
}
