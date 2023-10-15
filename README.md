# Oberon-keyboard-tweaks

## Tutorial: how to make changes to the Project Oberon 2013 keyboard device driver code

My main motivation for this small programming project was to get the arrow keys working in [Project Oberon 2013](https://people.inf.ethz.ch/wirth/ProjectOberon/index.html), a.k.a. Oberon System V5, for editing text and for playing ObTris (Oberon Tetris). It was fun to figure out some intricacies of the Keyboard Table `KTabAdr` in procedure `Init` of module `Input.Mod`, which is not described in detail by Niklaus Wirth. 

The only information he gives (see the book [Project Oberon 2013](https://people.inf.ethz.ch/wirth/ProjectOberon/PO.System.pdf), Section 9.2) is that it is a translation table which does a conversion from keyboard codes to ASCII character values. You need not understand much about the function `SYSTEM.ADR()` that uses the table, other than that it loads a string of at most 256 bytes somewhere into core memory and returns its address; so the Keyboard Table (KTab or kbdTab) can be seen as an array of 256 bytes. The indices of this array (coordinates of the table) are the keyboard codes (a.k.a. scan codes), and the bytes within the array are the hexadecimal ASCII values of characters. If you're curious you can find the code for `SYSTEM.ADR` in `ORS.HexString`, `ORG.Adr` and `ORG.loadStringAdr`.

### Reading the keyboard table

The table of hexadecimal numbers in procedure `Input.Init` has 16 rows and 16 columns. If we give the rows and columns of the table hexadecimal numbers starting with 0 for the upper row and the leftmost column (see below) then we can find the indices (key codes) for the locations in the table quite easily. Wirth already put an extra space between columns 7 and 8; for clarity you could put an extra white line below row 7 (for the functioning of `SYSTEM.ADR` that is no problem; but don't put the extra numbers and letters around the table as I did below!). 

For example, on most keyboards the key for the small letter "a" (= `61X`) has hexadecimal keyboard code 1C (`1CH`); you can find this character (`61` hex) in row number 1 and column number C, so its index (location in the table) is 1C. 
The key for capital letter "A" (= `41X`) has keyboard code `9C`, and you can find ASCII code `41` hex in row 9, in the same column C as `61` (= "a"), but eight rows below it.
The *escape key* (ASCII 27 decimal = `1B` hexadecimal) can be found twice: in row 7, column 6 and in row F, column 6; keyboard codes `76H` and `0F6H` are for esc and shift+esc respectively. [One might question the usefulness of the last item because not many people will use the combination of shift+esc if it serves the same purpose as esc alone. The same goes for two other double registrations of characters: `7F` (*delete*, `DEL`) and `08` (*backspace*, `BS`)]. 
```
       0  1  2  3  4  5  6  7   8  9  A  B  C  D  E  F

   0  00 00 00 00 00 1A 00 00  00 00 00 00 00 09 60 00
   1  00 00 00 00 00 71 31 00  00 00 7A 73 61 77 32 00
   2  00 63 78 64 65 34 33 00  00 20 76 66 74 72 35 00
   3  00 6E 62 68 67 79 36 00  00 00 6D 6A 75 37 38 00
   4  00 2C 6B 69 6F 30 39 00  00 2E 2F 6C 3B 70 2D 00
   5  00 00 27 00 5B 3D 00 00  00 00 0D 5D 00 5C 00 00
   6  00 00 00 00 00 00 08 00  00 00 00 00 00 00 00 00
   7  00 7F 00 00 00 00 1B 00  00 00 00 00 00 00 00 00

   8  00 00 00 00 00 00 00 00  00 00 00 00 00 09 7E 00
   9  00 00 00 00 00 51 21 00  00 00 5A 53 41 57 40 00
   A  00 43 58 44 45 24 23 00  00 20 56 46 54 52 25 00
   B  00 4E 42 48 47 59 5E 00  00 00 4D 4A 55 26 2A 00
   C  00 3C 4B 49 4F 29 28 00  00 3E 3F 4C 3A 50 5F 00
   D  00 00 22 00 7B 2B 00 00  00 00 0D 7D 00 7C 00 00
   E  00 00 00 00 00 00 08 00  00 00 00 00 00 00 00 00
   F  00 7F 00 00 00 00 1B 00  00 00 00 00 00 00 00 00$)
```

How to proceed to get the arrow keys (*left*, *right*, *up* and *down*) of your keyboad into the Keyboard Table?
First find out which keyboard codes they produce.

To find out the keyboard code for a particular key of your keyboard you can use my procedure `ShowKey` in module `TestInput.Mod`. This procedure uses the preprocessing that is provided by procedures `Peek` and `Read` of module `Input.Mod`.

In my case (using a MacBook) the keyboard codes are as follows:
*left*: `0EBH`    *right*: `0F4H`    *up*: `0F5H`    *down*: `0F2H`

The keyboard codes you find for your own arrow keys indicate the location in the table where the ASCII codes for these keys should be placed. But what are their ASCII codes? Well, you are free to choose them yourself from the ASCII codes that Oberon does not use! You should choose four characters from the range `01X` to `1FX` (the *ASCII control characters*). The following control characters are in use by Oberon: (*backspace*, `BS` (`8X`), *tabulator*, `TAB` (`9X`), *carriage return*, `CR` (`0DX`), *ctrl-C* (`3X`, copy), *ctrl-V* (`16X`, paste), *ctrl-X* (18X, cut), (*ctrl-Z* (`1AX`, place the star marker), so don't use one of those. 

Note that ctrl-key combinations are handled by procedure `Input.Read` (without using the Keyboard Table) in the line:
```
    IF Ctrl THEN ch := CHR(ORD(ch) MOD 20H) END
```
ASCII codes that are often used for the arrow keys are:
*left*: `11X` (`^Q`),  *right*: `12X` (`^R`),   *up*: `13X` (`^S`),   *down*: `14X` (`^T`)

I chose other ASCII codes that have better mnemonics for the control combinations (just for fun): 
*left*: `2X` (`^B` backward), *right*: `6X` (`^F` forward), `uP`: `10X` (`^P`), *dowN*: `0EX` (`^N`)

So my Keyboard Table looks like this (I also added the codes for one extra key of the Dutch MacBook keyboard: `60` and `7E`, which is de key for ` and ~):
```
    KTabAdr := SYSTEM.ADR($
      00 00 00 00 00 1A 00 00  00 00 00 00 00 09 60 00
      00 00 00 00 00 71 31 00  00 00 7A 73 61 77 32 00
      00 63 78 64 65 34 33 00  00 20 76 66 74 72 35 00
      00 6E 62 68 67 79 36 00  00 00 6D 6A 75 37 38 00
      00 2C 6B 69 6F 30 39 00  00 2E 2F 6C 3B 70 2D 00
      00 00 27 00 5B 3D 00 00  00 00 0D 5D 00 5C 00 00
      00 60 00 00 00 00 08 00  00 00 00 00 00 00 00 00
      00 7F 00 00 00 00 1B 00  00 00 00 00 00 00 00 00

      00 00 00 00 00 00 00 00  00 00 00 00 00 09 7E 00
      00 00 00 00 00 51 21 00  00 00 5A 53 41 57 40 00
      00 43 58 44 45 24 23 00  00 20 56 46 54 52 25 00
      00 4E 42 48 47 59 5E 00  00 00 4D 4A 55 26 2A 00
      00 3C 4B 49 4F 29 28 00  00 3E 3F 4C 3A 50 5F 00
      00 00 22 00 7B 2B 00 00  00 00 0D 7D 00 7C 00 00
      00 7E 00 00 00 00 08 00  00 00 00 02 00 00 00 00
      00 7F 0E 00 06 10 1B 00  00 00 00 00 00 00 00 00$)
```

After changing the Keyboard Table, add the following line to the constant declaration of Input.Mod (using the ASCII codes that you chose for the arrow keys):
```
CONST
  (...)
  left* = 02X;  right* = 06X;  up* = 10X;  down* = 0EX;        (* cursor control characters *)
```

Then insert the following code fragment into procedure Write of TextFrames.Mod (again using your own chosen ASCII codes for the arrow keys and matching control characters): 
```
    (...)
  ELSIF ch = 18X THEN (*ctrl-x,  cut*)
    IF F.hasSel THEN
      NEW(TBuf); Texts.OpenBuf(TBuf); Texts.Delete(F.text, F.selbeg.pos, F.selend.pos, TBuf)
    END
(* ---------- start arrow keys fragment --------------------------------------------------- *)
  ELSIF (ch = Input.left) OR Input.Ctrl & (ch = 2X) (*Ctrl+B*) THEN       (* left, Backward *)
    IF F.carloc.pos > 0 THEN RemoveCaret(F); SetCaret(F, F.carloc.pos - 1) END
  ELSIF (ch = Input.right) OR Input.Ctrl & (ch = 6X) (*Ctrl+F*) THEN      (* right, Forward *)
    IF F.carloc.pos < F.text.len THEN RemoveCaret(F); SetCaret(F, F.carloc.pos + 1) END
  ELSIF (ch = Input.up) OR Input.Ctrl & (ch = 10X) (*Ctrl+P*) THEN                    (* uP *)
    RemoveCaret(F); SetCaret(F, Pos(F, F.X + F.carloc.x, F.Y + F.carloc.y + F.lsp))
  ELSIF (ch = Input.down) OR Input.Ctrl & (ch = 0EX) (*Ctrl+N*) THEN                (* dowN *)
    RemoveCaret(F); SetCaret(F, Pos(F, F.X + F.carloc.x, F.Y + F.carloc.y - F.lsp))		
(* ---------- end   arrow keys fragment --------------------------------------------------- *)
  ELSIF (20X <= ch) & (ch <= DEL) OR (ch = CR) OR (ch = TAB) THEN
    (...)
```
While you are editing TextFrames.Mod you might as well make one further change to the procedure Write, to get the delete key (forward delete) working in Oberon System texts. For this you need not change anything in the Keyboard Table of `Input.Mod` because the delete key is already there (ASCII `7F` in locations F1 and 71). You only need to make the following changes to procedure Write, a few lines above the changes you made for the arrow keys (if you know a simpler code for this, please let me know):
```
    (...)
BEGIN (*F.hasCar*)
  IF ch = BS THEN  (*backspace*)
    IF F.carloc.pos > F.org THEN
      Texts.Delete(F.text, F.carloc.pos - 1, F.carloc.pos, DelBuf); SetCaret(F, F.carloc.pos - 1)
    END
(* ---------- start DEL fragment ------------------------------------------------------------- *)
  ELSIF ch = DEL THEN (* delete *)
    IF F.carloc.pos > F.org THEN
      (* move caret 1 char right and then backspace *)
      IF F.carloc.pos < F.text.len THEN RemoveCaret(F); SetCaret(F, F.carloc.pos + 1) END;
      Texts.Delete(F.text, F.carloc.pos - 1, F.carloc.pos, DelBuf); SetCaret(F, F.carloc.pos - 1)
    END		
(* ---------- end DEL fragment --------------------------------------------------------------- *)
  ELSIF ch = 3X THEN (* ctrl-c  copy*)
      (...)
```

Finally recompile `Input.Mod` and `TextFrames.Mod` and all modules that are dependent on them. 
At least recompile the following modules by middle-clicking on `ORP.Compile` in each line, in a strict downward order:
```
ORP.Compile Input.Mod/s  Display.Mod/s  Viewers.Mod/s ~
ORP.Compile Fonts.Mod/s  Texts.Mod/s ~
ORP.Compile Oberon.Mod/s ~
ORP.Compile MenuViewers.Mod/s ~
ORP.Compile TextFrames.Mod/s ~
ORP.Compile System.Mod/s ~
ORP.Compile Edit.Mod/s ~
ORP.Compile ORS.Mod/s  ORB.Mod/s ~
ORP.Compile ORG.Mod/s  ORP.Mod/s ~
```
Then restart the Oberon System.

