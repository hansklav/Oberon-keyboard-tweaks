(* TestInput.ShowKey  TestInput.KbdTab      TestInput.ShowMem *)

MODULE TestInput; (* IN V5 *)  (* hk  20-10-2023 *)

  IMPORT SYSTEM, Input, Out;

  CONST 
    msAdr = -40;  kbdAdr = -36;
    tab = 09X;
    H = TRUE;  noH = FALSE;  (* 2nd parameter of Out.ByteHex: H after hexadecimal? *)

  VAR
    kbdCode: BYTE;           (* last keyboard code read *)
    Recd, Up, Shift, Ctrl, Ext: BOOLEAN;
    kbdTabAdr: INTEGER;      (* address of keyboard code translation table *)


  PROCEDURE Peek;
  BEGIN
    IF SYSTEM.BIT(msAdr, 28) THEN  (* this flag signals that a keyboard code was received in the buffer *)
      SYSTEM.GET(kbdAdr, kbdCode);           (* get the most recent keyboard code *)
      IF kbdCode = 0F0H THEN Up := TRUE      (* keyboard code 0F0H signals key up *)
      ELSIF kbdCode = 0E0H THEN Ext := TRUE  (* keyboard code 0E0H signals extended code *)
      ELSE
        IF (kbdCode = 12H) OR (kbdCode = 59H) THEN (*shift*) Shift := ~Up  (* Shift is only TRUE when the key is down *)
        ELSIF kbdCode = 14H THEN (*ctrl*) Ctrl := ~Up                      (* Ctrl is only TRUE when the key is down *)
        ELSIF ~Up THEN Recd := TRUE (*real key going down*)
        END ;
        Up := FALSE; Ext := FALSE
      END
    END
  END Peek;

  PROCEDURE Available (): INTEGER;
  BEGIN  
    Peek();
  RETURN ORD(Recd)
  END Available;

  PROCEDURE Read (VAR ch: CHAR);
  BEGIN
    WHILE ~Recd DO Peek() END ;
    IF Shift OR Ctrl THEN INC(kbdCode, 80H) END;  (*ctrl implies shift*)
    SYSTEM.GET(kbdTabAdr + kbdCode, ch);          (* ch := kbdTab[kbdCode]; *)
    IF Ctrl THEN ch := CHR(ORD(ch) MOD 20H) END;  (* Ctrl characters overrule characters from the table *)
    Recd := FALSE
  END Read;


  PROCEDURE ShowKey*;
  (* Waits for a key press and reports the keycode, ASCII-code and character (if visible) *)
    VAR i, n: INTEGER; ch: CHAR;
  BEGIN
 (* Out.SetFont("Courier10.Fnt"); *)
    Out.String("Press any key ... (Q or q exits)");  Out.Ln; 
    REPEAT
      REPEAT n := Available( ) UNTIL n > 0;
      FOR i := 1 TO n DO
        Read(ch);
        Out.String("kbdCode: "); Out.ByteHex(kbdCode, noH);
        Out.String("  Char: "); Out.CharHex(ch); Out.String(" = "); Out.Char(ch); Out.Ln;
        Out.String("  Shift: "); Out.Bool(Shift);  
        Out.String("   Ctrl: "); Out.Bool(Ctrl);  
        Out.String("   Ext: "); Out.Bool(Ext); 
        Out.Ln;
        Shift := FALSE; Ctrl := FALSE; Ext := FALSE;
      END
    UNTIL (ch = "q") OR (ch = "Q");
    Out.Ln
  END ShowKey;


  PROCEDURE KbdTab*;  (* TestInput.KbdTab *)
  (* Prints the contents of the Keyboard Table in readable format *)
    VAR adr, line, i, v: INTEGER;  ch: CHAR;
  BEGIN 
 (* Out.SetFont("Courier10.Fnt"); *)
    Out.String("Keyboard Code Table"); Out.Ln;
    Out.String("Line KbCode ASCII Char"); Out.Ln;
    line := 0; 
    FOR i := 0 TO 255 DO
      IF i > 0 THEN
        IF i MOD 16 = 0 THEN INC(line); Out.Ln 
        ELSIF i MOD 8 = 0 THEN Out.Ln
        END
      END;
      SYSTEM.GET(kbdTabAdr + i, ch);
      Out.Int(line, 2);     Out.String("    ");
      Out.ByteHex(i, noH); Out.String("H    "); 
      IF ch < 0AX THEN Out.Char("0") END; Out.CharHex(ch); Out.String("   ");
      IF ch = 7X THEN Out.String("BEL")
      ELSIF ch = 8X THEN Out.String("BS")
      ELSIF ch = 9X THEN Out.String("TAB")
      ELSIF ch = 0DX THEN Out.String("CR")
      ELSIF ch = 1BX THEN Out.String("ESC")
      ELSIF ch = 20X THEN Out.String("SP")
      ELSIF ch = 7FX THEN Out.String("DEL")
      (* if you chose other ASCII characters for your arrow keys 
         in Input.Mod change them accordingly below *)
      ELSIF ch = 2X THEN Out.String("LEFT")
      ELSIF ch = 6X THEN Out.String("RIGHT")
      ELSIF ch = 10X THEN Out.String("UP")
      ELSIF ch = 0EX THEN Out.String("DOWN")
      ELSE Out.Char(ch)
      END; Out.Ln
    END
  END KbdTab;


  PROCEDURE ShowMem*;  (* TestInput.ShowMem *)
  (* Explores how SYSTEM.ADR($ ..$) works *)
    VAR
      adr, i, x, x0, x1: INTEGER;  v, b: BYTE;  ch: CHAR;
  BEGIN
    (* show bytes *)
    adr := SYSTEM.ADR($ 12 34 56 78 91 23 45 67 89 12$);  (* no space allowed between last digit and $ *)
    FOR i := 0 TO 9 DO
      SYSTEM.GET(adr + i, b);
      Out.ByteHex(b, TRUE); Out.String(" "); 
    END;
    Out.Ln; 

    (* show integer *)
    adr := SYSTEM.ADR($ 10 20 30 40 50 60 70 80$);  (* no space allowed between last digit and $ *)
    SYSTEM.GET(adr, x0);  SYSTEM.GET(adr + SYSTEM.SIZE(INTEGER), x1); 
    Out.String("SYSTEM.SIZE(INTEGER) = "); Out.Int(SYSTEM.SIZE(INTEGER), 0); Out.Ln;
    Out.String("x0 = "); Out.Int(x0, 0); Out.String(" = "); Out.IntHex(x0); Out.Ln;
    Out.String("x1 = "); Out.Int(x1, 0); Out.String(" = "); Out.IntHex(x1); Out.Ln;

    (* show byte *) 
    adr := SYSTEM.ADR($ 80$);  (* no space allowed between last digit and $, else compile error 'hexdig expected' *)
    SYSTEM.GET(adr, v);
    Out.Int(v, 0); Out.Ln;
    Out.ByteHex(v, H); Out.Ln;
    Out.IntHex(v); Out.Ln; 
    Out.Ln;
  END ShowMem;


  PROCEDURE Init*;
  (* If you made changes to the keyboard table in Input.Init then copy 
    the changed table here to see all the changes *)
  BEGIN Up := FALSE;  Shift := FALSE;  Ctrl := FALSE;  Recd := FALSE;
    kbdTabAdr := SYSTEM.ADR($
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
  END Init;


BEGIN Init
END TestInput.
