MODULE ObTris; (* V1.0 (C) 1 Nov 1995 by Ralf Degner, E-Mail: degner@pallas.amp.uni-hannover.de *)

(* jr/21dec20: adapted to Oberon-07 and PO2013 *)
(* hk/11jun21: altered score board and use of arrow keys *)

IMPORT R := Random,
	SYSTEM, Files, Input, Display, Viewers, Fonts, Texts, Oberon, MenuViewers, TextFrames, Strings;

CONST
	red = 1;  blue = 3;  green = 2;  yellow = 5;  col1 = 4;  col2 = 6;  col3 = 7;
	Menu = "System.Close  System.Copy  System.Grow  ObTris.Start  ObTris.ShowNext  ObTris.Score";
	XAnzahl = 10;  YAnzahl = 24;  MinKasten = 4;
	UntenOffset = 10;  ObenOffset = 4;  SeitenOffset = 10;  NextXPos = -5;  NextYPos = YAnzahl DIV 2;
	LinesProLevel = 10;  SpeedUpProLevel = 20;  ScoreFakt = 10;  ScoreFileMark = 06C6F6976H;

	left = Input.left;  right = Input.right;  up = Input.up;  down = Input.down;

TYPE
	String = ARRAY 8 OF CHAR;

	Game = POINTER TO GameDesc;
	GameDesc = RECORD
		Field: ARRAY XAnzahl + 2 OF ARRAY YAnzahl + 2 OF INTEGER;
		Runs, ShowNext: BOOLEAN;
		Delay, Score, Level, Lines, DateT: LONGINT;
		x, y, p, fig, next: INTEGER;
	END;

	Frame = POINTER TO FrameDesc;
	FrameDesc = RECORD(Display.FrameDesc)
		XOffset, YOffset: INTEGER;
		Kasten: INTEGER;  (* box *)
		Aktiv: BOOLEAN;
		G: Game;
	END;

	ObTrisMsg = RECORD(Display.FrameMsg)
	END;

	DrawMsg = RECORD(ObTrisMsg)
		G: Game;
	END;

VAR
	W: Texts.Writer;
	Name: String;  (* ObTris username, ARRAY 8 OF CHAR *)
	(*Seed,*) Delay: LONGINT;
	Fig: ARRAY 8 OF ARRAY 4 OF ARRAY 4 OF ARRAY 4 OF INTEGER;
	FigSize: ARRAY 8 OF INTEGER;
	gameOver: BOOLEAN;
	HiRank: INTEGER;
	HiScore, HiLevel, HiLines, HiDateT: ARRAY 10 OF INTEGER;
	HiName: ARRAY 10 OF String;
	ScoreFile: Files.File;
	ScoreRider: Files.Rider;
	ch: ARRAY 7 OF CHAR;  (* game control keys *)


(* Generate Random Numbers *)
PROCEDURE Random(Ein: INTEGER): INTEGER;
	RETURN R.Range(Ein)
END Random;


(* Print current Keys *)
PROCEDURE PrintKeys;
	VAR d: INTEGER;
BEGIN
	Texts.WriteString(W, "Current Keys: ");
	FOR d := 0 TO 5 DO
		IF ch[d]       = left THEN Texts.WriteString(W, "LEFT")
		ELSIF ch[d] = right THEN Texts.WriteString(W, "RIGHT")
		ELSIF ch[d] = up THEN Texts.WriteString(W, "UP")
		ELSIF ch[d] = down THEN Texts.WriteString(W, "DOWN")

		ELSIF ch[d] = 0DX THEN Texts.WriteString(W, "RETURN")
		ELSIF ch[d] = 1BX THEN Texts.WriteString(W, "ESC")
		ELSIF ch[d] = 09X THEN Texts.WriteString(W, "TAB")
		ELSIF ch[d] = 20X THEN Texts.WriteString(W, "SPACE")
		ELSE Texts.Write(W, ch[d])
		END;
		Texts.Write(W, " ");
	END;
	Texts.WriteLn(W);
END PrintKeys;


(* Store HiScore from memory into a file *)
PROCEDURE SaveHi(Register: BOOLEAN);
	VAR d: INTEGER;
BEGIN
	Files.Set(ScoreRider, ScoreFile, 0);
	Files.WriteInt(ScoreRider, ScoreFileMark);       (* write a magic number used as a file type signature *)
	FOR d := 0 TO 5 DO
		Files.Write(ScoreRider, ch[d])                      (* write the current six game control keys *)
	END;

	FOR d := 0 TO 9 DO
		Files.WriteString(ScoreRider, HiName[d]);  (* write the current ten high scores *)
		Files.WriteInt(ScoreRider, HiScore[d]);
		Files.WriteInt(ScoreRider, HiLevel[d]);
		Files.WriteInt(ScoreRider, HiLines[d]);
		Files.WriteInt(ScoreRider, HiDateT[d])
	END;

	IF Register THEN
		Files.Register(ScoreFile)
	ELSE
		Files.Close(ScoreFile)
	END
END SaveHi;


(* Load HiScore from file into memory *)
PROCEDURE LoadHi();
	VAR
		d: INTEGER;
		m: LONGINT;

	PROCEDURE ClearHi();
		VAR n: INTEGER;
	BEGIN
	  (* game control keys: 
    left,           right,           flipleft,      flipright,     drop,           pause         *)
 (* ch[0] := "j";   ch[1] := "k";    ch[2] := "i";  ch[3] := "m";  ch[4] := "h";   ch[5] := "p"; *)
		ch[0] := left;  ch[1] := right;  ch[2] := up;   ch[3] := "/";  ch[4] := down;  ch[5] := "p";
		FOR n := 0 TO 9 DO
			HiScore[n] := 0;  HiLevel[n] := 0;  HiLines[n] := 0;
			HiName[n] := "Amiga";
		END
	END ClearHi;

BEGIN
	ScoreFile := Files.Old("ObTris.Score"); 
	IF ScoreFile = NIL THEN  (* no scorefile found *)
		ScoreFile := Files.New("ObTris.Score");
		ClearHi();         (* reset all data for the new scorefile *)
		SaveHi(TRUE)  (* TRUE: register this filename in the directory *)
	ELSE  (* work with existing scorefile *)
		Files.Set(ScoreRider, ScoreFile, 0);
		Files.ReadInt(ScoreRider, m);  (* read the magic number used as a file type signature *)
		IF m = ScoreFileMark THEN
			FOR d := 0 TO 5 DO
				Files.Read(ScoreRider, ch[d])  (* read the game control key settings *)
			END;
			FOR d := 0 TO 9 DO  (* read the ten highest scores up to now *)
				Files.ReadString(ScoreRider, HiName[d]);
				Files.ReadInt(ScoreRider, HiScore[d]);
				Files.ReadInt(ScoreRider, HiLevel[d]);
				Files.ReadInt(ScoreRider, HiLines[d]);
				Files.ReadInt(ScoreRider, HiDateT[d])
			END
		ELSE  (* no ScoreFileMark found, so file corrupted (?) *)
			ClearHi();
			SaveHi(FALSE)
		END
	END
END LoadHi;


(* New Score for Hall of Fame? If Yes, Register *)
PROCEDURE RegisterScore (s, le, li: LONGINT);
	VAR d, n: LONGINT;

	PROCEDURE CopyPadded (source: ARRAY OF CHAR; VAR dest: ARRAY OF CHAR);
	(* Now all name strings have the same Length, for a pretty HiScore table *)
		VAR
			i, max: INTEGER;  ch: CHAR;
	BEGIN
		i := 0;  max := LEN(dest);  ch := source[0];
		WHILE (ch # 0X) & (i < max - 1) DO dest[i] := ch; INC(i); ch := source[i] END;
		IF ch = 0X THEN
			WHILE i < max - 1 DO dest[i] := " "; INC(i) END
		END;
		dest[i] := 0X
	END CopyPadded;

BEGIN
	d := 9;
	WHILE (d # -1) & (HiScore[d] < s) DO DEC(d); END;
	IF d # 9 THEN
		INC(d);
		IF d < 9 THEN
			FOR n := 8 TO d BY -1 DO
				HiName[n + 1] := HiName[n];  HiScore[n + 1] := HiScore[n];
				HiLevel[n + 1] := HiLevel[n];  HiLines[n + 1] := HiLines[n];
				HiDateT[n + 1] := HiDateT[n]
			END
		END;
		HiRank := d + 1;
		CopyPadded(Name, HiName[d]);
		HiScore[d] := s;  HiLevel[d] := le;  HiLines[d] := li;
		HiDateT[d] := Oberon.Clock( );
		Texts.WriteString(W, Name); Texts.WriteString(W, " entering Hall of Fame ..."); Texts.WriteLn(W);
		SaveHi(FALSE)
	END
END RegisterScore;


(* Draw one Kasten (Kasten = box) *)
PROCEDURE DrawKasten (f: Frame; x, y, COLOR: INTEGER);
	VAR XDum, YDum: INTEGER;
BEGIN
	XDum := f.XOffset + (f.Kasten * (x - 1));
	YDum := f.YOffset + (f.Kasten * (y - 1));
(*
	Display.ReplConst(Display.white, XDum, YDum, f.Kasten - 1, f.Kasten - 1, Display.paint);
*)
	Display.ReplConst(COLOR, XDum+1, YDum+1, f.Kasten - 3, f.Kasten - 3, Display.paint)
END DrawKasten;


(* Clear one Kasten *)
PROCEDURE ClearKasten (f: Frame; x, y: INTEGER);
	VAR XDum, YDum: INTEGER;
BEGIN
	XDum := f.XOffset + (f.Kasten * (x - 1));
	YDum := f.YOffset + (f.Kasten * (y - 1));
	Display.ReplConst(Display.black, XDum, YDum, f.Kasten - 1, f.Kasten - 1, Display.replace)
END ClearKasten;


(* Draw Figure *)
PROCEDURE DrawFig (f: Frame; x, y, fi, pos: INTEGER);
	VAR CountX, CountY, col: INTEGER;
BEGIN
	FOR CountX := 0 TO 3 DO
		FOR CountY := 0 TO 3 DO
			col := Fig[fi, pos, CountX, CountY];
			IF col # 0 THEN DrawKasten(f, CountX + x, CountY + y, col) END
		END
	END
END DrawFig;


(* Clear Figure *)
PROCEDURE ClearFig (f: Frame; x, y, fi, pos: INTEGER);
	VAR CountX, CountY, col: INTEGER;
BEGIN
	FOR CountX := 0 TO 3 DO
		FOR CountY := 0 TO 3 DO
			col := Fig[fi, pos,CountX,CountY];
			IF col # 0 THEN ClearKasten(f, CountX + x, CountY + y) END
		END
	END
END ClearFig;


(* Register Figure at Field *)
PROCEDURE RegisterFig (G: Game; x, y, fi, pos: INTEGER);
	VAR CX, CY, col: INTEGER;
BEGIN
	FOR CX := 0 TO 3 DO
		FOR CY := 0 TO 3 DO
			col := Fig[fi, pos,CX,CY];
			IF col # 0 THEN G.Field[CX+x, CY+y] := col END
		END
	END
END RegisterFig;


(* Test, if Figure fits to given Position *)
PROCEDURE TestFig (G: Game; x, y, fi, pos: INTEGER): BOOLEAN;
	VAR CountX, CountY, col, state: INTEGER;
BEGIN
	CountX := 0; CountY := 0; state := 0;
	REPEAT
		col := Fig[fi, pos, CountX, CountY];
		IF (col # 0) & (G.Field[CountX + x, CountY + y] # 0) THEN state := 1 (* does not fit *) END;
		INC(CountY);
		IF CountY > 3 THEN CountY := 0; INC(CountX); IF CountX > 3 THEN state := 2 (* does fit *) END END;
	UNTIL state > 0
	RETURN state = 2
END TestFig;


(* Calc Size of one Kasten, depending on Size of Frame *)
PROCEDURE CalcKasten(f: Frame; x, y, w, h: INTEGER);
	VAR XKasten, YKasten: INTEGER;
BEGIN
	f.Aktiv := TRUE;
	YKasten := (h - ObenOffset - UntenOffset) DIV YAnzahl;

	IF f.G.ShowNext THEN
		XKasten := (w - 2 * SeitenOffset) DIV (XAnzahl - NextXPos)
	ELSE
		XKasten := (w - 2 * SeitenOffset) DIV XAnzahl
	END;

	IF (XKasten < MinKasten) OR (YKasten < MinKasten) THEN
		f.Aktiv := FALSE

	ELSE

		IF XKasten < YKasten THEN
			f.Kasten := XKasten
		ELSE
			f.Kasten := YKasten
		END;

		IF f.G.ShowNext THEN
			f.XOffset := x + (w - f.Kasten * (XAnzahl + NextXPos)) DIV 2
		ELSE
			f.XOffset := x + (w - f.Kasten*XAnzahl) DIV 2
		END;
		f.YOffset:=y+(h-f.Kasten*YAnzahl) DIV 2
	END
END CalcKasten;


(* Redraw Field *)
PROCEDURE RedrawField(f: Frame);
	VAR XD, YD, col: INTEGER;
BEGIN
	FOR YD := 1 TO YAnzahl DO
		FOR XD := 1 TO XAnzahl DO
			col := f.G.Field[XD, YD];
			IF col = 0 THEN ClearKasten(f, XD, YD)
			ELSE 				DrawKasten(f, XD, YD, col)
			END
		END
	END
END RedrawField;


(* Search and Delete full Lines *)
PROCEDURE KillLines(f: Frame);
	VAR
		CountX, CountY, Killed: INTEGER;
		quit: BOOLEAN;

	PROCEDURE KillLine(VAR G: Game; l: INTEGER);
		VAR CountX, CountY: INTEGER;
	BEGIN
		FOR CountY := l + 1 TO YAnzahl - 1 DO
			FOR CountX := 1 TO XAnzahl DO G.Field[CountX, CountY - 1] := G.Field[CountX, CountY] END
		END;
		FOR CountX := 1 TO XAnzahl DO G.Field[CountX, YAnzahl] := 0 END
	END KillLine;

BEGIN
	Killed := 0;
	FOR CountY := YAnzahl - 1 TO 1 BY -1 DO
		CountX := 1; quit := FALSE;
		REPEAT
			IF f.G.Field[CountX, CountY] = 0 THEN quit := TRUE
			ELSIF CountX = XAnzahl THEN
				INC(Killed);
				KillLine(f.G, CountY);
				quit := TRUE
			END;
			INC(CountX)
		UNTIL quit
	END;

	IF Killed # 0 THEN
		RedrawField(f);
		f.G.Lines := f.G.Lines + Killed;
		f.G.Score := Killed * 2 - 1 + f.G.Score
	END;

	IF (f.G.Lines DIV LinesProLevel) > f.G.Level THEN
		INC(f.G.Level); INC(f.G.Score, LinesProLevel DIV 2);
		f.G.Delay := (f.G.Delay * (100 - SpeedUpProLevel)) DIV 100
	END
END KillLines;


(* Clear Field *)
PROCEDURE ClearField(G: Game);
	VAR XDum, YDum: INTEGER;
BEGIN
	FOR XDum := 1 TO XAnzahl DO
		FOR YDum := 1 TO YAnzahl  DO
			G.Field[XDum, YDum] :=  0
		END
	END;

	FOR YDum := 0 TO YAnzahl DO
		G.Field[0, YDum] := 1;
		G.Field[XAnzahl + 1, YDum] := 1;
	END;

	FOR XDum := 0 TO XAnzahl + 1 DO
		G.Field[XDum, 0] := 1;
		G.Field[XDum, YAnzahl + 1] := 1
	END
END ClearField;


(* Clear Frame and Draw everything necessary *)
PROCEDURE ClearFrame(f: Frame; x, y, w, h: INTEGER);
	VAR XDum, YDum: INTEGER;
BEGIN
	Oberon.RemoveMarks(x, y, w, h);
	Display.ReplConst(Display.black, x, y, w, h, Display.replace);
	IF f.Aktiv THEN
		XDum:=f.Kasten*XAnzahl+1;
		YDum:=f.Kasten*YAnzahl;
		Display.ReplConst(Display.white, f.XOffset-3, f.YOffset-3, XDum+4, YDum+3, Display.paint);
		Display.ReplConst(Display.black, f.XOffset-1, f.YOffset-1, XDum, YDum+1, Display.replace);
		IF f.G.ShowNext THEN
			XDum:=f.XOffset+f.Kasten*NextXPos-3;
			YDum:=f.YOffset+f.Kasten*NextYPos-3;
			Display.ReplConst(Display.white, XDum, YDum, 4*f.Kasten+5, 2*f.Kasten+5, Display.paint);
			Display.ReplConst(Display.black, XDum+2, YDum+2, 4*f.Kasten+1, 2*f.Kasten+1, Display.replace);
		END;
		RedrawField(f);
		IF f.G.Runs THEN
			DrawFig(f, f.G.x, f.G.y, f.G.fig, f.G.p);
			IF f.G.ShowNext THEN DrawFig(f, NextXPos+1, NextYPos+1, f.G.next, 0) END
		END
	END
END ClearFrame;


(* copy frame with same data *)
PROCEDURE CopyMe (f: Frame): Frame;
	VAR nf: Frame;
BEGIN
	NEW(nf);
	IF nf # NIL THEN nf.handle := f.handle; nf.G := f.G END
RETURN nf END CopyMe;


(* Open MenuFrame with ObTris.Menu.Text *)
PROCEDURE MenuFrame(): TextFrames.Frame;
	VAR
		mf: TextFrames.Frame;
		buf: Texts.Buffer;
		t: Texts.Text;
		r: Texts.Reader;
		end: LONGINT;
		ch: CHAR;
BEGIN
	IF Files.Old("ObTris_Menu.Text")=NIL THEN
		mf:=TextFrames.NewMenu("ObTris", Menu)
	ELSE
		mf:=TextFrames.NewMenu("ObTris", "");
		NEW(t);Texts.Open(t, "ObTris_Menu.Text");
		Texts.OpenReader(r, t, 0);
		REPEAT
			Texts.Read(r, ch)
		UNTIL r.eot OR (ch=0DX);
		IF r.eot THEN
			end:=t.len
		ELSE
			end:=Texts.Pos(r)-1;
		END;
		NEW(buf); Texts.OpenBuf(buf);
		Texts.Save(t, 0, end, buf);Texts.Append(mf.text, buf)
	END
	RETURN mf
END MenuFrame;


(* Open new Text-Frame *)
PROCEDURE OpenViewer(text: Texts.Text);
	VAR x, y: INTEGER; v: Viewers.Viewer; cf: TextFrames.Frame;
BEGIN
	Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, x, y);
	cf := TextFrames.NewText(text, 0);
	v := MenuViewers.New(TextFrames.NewMenu("ObTris Hall of Fame", "System.Close  System.Copy  System.Grow"),
										cf, TextFrames.menuH, x, y)
END OpenViewer;


(* Handler of an ObTris Frame *)
PROCEDURE Handler(f: Display.Frame; VAR m: Display.FrameMsg);
	VAR self: Frame;
BEGIN
	self:=f(Frame);
	CASE m OF
	Oberon.InputMsg:
		IF m.id=Oberon.track THEN Oberon.DrawMouseArrow(m.X, m.Y) END
	| Oberon.CopyMsg:
		m.F:=CopyMe(self)
	| MenuViewers.ModifyMsg:
			IF m.H#0 THEN
				CalcKasten(self, f.X, m.Y, f.W, m.H);
				ClearFrame(self, f.X, m.Y, f.W, m.H)
			END
	| DrawMsg:
			IF m.G=self.G THEN
				CalcKasten(self, f.X, f.Y, f.W, f.H);
				ClearFrame(self, f.X, f.Y, f.W, f.H)
			END
	END
END Handler;


(* get current/marked Frame *)
PROCEDURE GetFrame(VAR f: Display.Frame): BOOLEAN;
	VAR v: Viewers.Viewer;
		found: BOOLEAN;
BEGIN
	found := FALSE;
	IF Oberon.Par.frame=Oberon.Par.vwr.dsc THEN
		IF (Oberon.Par.frame # NIL) THEN
			f:=Oberon.Par.frame.next;
			found := TRUE
		END
	ELSE
		v:=Oberon.MarkedViewer();
		IF (v.dsc # NIL) & (v.dsc.next # NIL) THEN
			f:=v.dsc.next;
			found := TRUE
		END
	END
RETURN found
END GetFrame;


(* Calc System Speed *)
PROCEDURE CalcSysSpeed ( ): LONGINT;
	VAR
		StartTime, Duration, q, Anz: LONGINT;
		c: CHAR;
		f: Frame;
		x, y, fig, p, d: INTEGER;
BEGIN
	NEW(f); x:=0; y:=0; fig:=0; p:=0; Anz:=0;
	StartTime:=Oberon.Time(); ch[6]:=CHR(0);
	REPEAT
		FOR q:=0 TO 31 DO
			IF Input.Available() > 0 THEN
				Input.Read(c);
				IF (c=ch[6]) OR (c="P") OR (c="p") THEN
				ELSIF c=ch[6] THEN
					IF TestFig(f.G, x-1, y, fig, p) THEN
						ClearFig(f, x, y, fig, p);
						DEC(x);
						DrawFig(f, x, y, fig, p)
					END
				ELSIF c=ch[6] THEN
					IF TestFig(f.G, x+1, y, fig, p) THEN
						ClearFig(f, x, y, fig, p);
						INC(x);
						DrawFig(f, x, y, fig, p)
					END
				ELSIF c=ch[6] THEN
					d:=p+1; IF d=4 THEN d:=0; END;
					IF TestFig(f.G, x, y, fig, d) THEN
						ClearFig(f, x, y, fig, p);
						DrawFig(f, x, y, fig, d);
						p:=d
					END
				ELSIF c=ch[6] THEN
					d:=p-1; IF d=-1 THEN d:=3; END;
					IF TestFig(f.G, x, y, fig, d) THEN
						ClearFig(f, x, y, fig, p);
						DrawFig(f, x, y, fig, d);
						p:=d
					END
				ELSIF c=ch[6] THEN
					d:=y;
					WHILE TestFig(f.G, x, y-1, fig, p) DO DEC(y); END;
					ClearFig(f, x, d, fig, p);
					DrawFig(f, x, y, fig, p)
				END
			END
		END;
		INC(Anz, 31);
		Duration := Oberon.Time()- StartTime
	UNTIL Duration > 1000;
	RETURN Anz*Duration DIV 1000
END CalcSysSpeed;


(* Main-Loop of the Game *)
PROCEDURE GameLoop (f: Frame);
	VAR
		c: CHAR;
		DelCount: LONGINT;
		x, y, p, fig, next, d: INTEGER;
		msg: DrawMsg;
		done: BOOLEAN;
BEGIN
	x := f.G.x;  y := f.G.y;  p := f.G.p;  fig := f.G.fig;  next := f.G.next;
	f.G.Runs := TRUE;
	Oberon.RemoveMarks(f.X, f.Y, f.W, f.H);
	IF f.G.ShowNext THEN DrawFig(f, NextXPos + 1, NextYPos + 1, next, 0) END;

	done := FALSE;
	REPEAT
		IF TestFig(f.G, x, y - 1, fig, p) THEN
			ClearFig(f, x, y, fig, p);
			DEC(y);
			DrawFig(f, x, y, fig, p)
		ELSE
			RegisterFig(f.G, x, y, fig, p);
			KillLines(f);
			y := YAnzahl - 2; p := 0; fig := next; next := Random(7); x := ((XAnzahl - FigSize[fig]) DIV 2) + 1;
			IF fig = 1 THEN DEC(y); p := 2 END;
			IF ~TestFig(f.G, x, y, fig, p) THEN f.G.Runs := FALSE; done := TRUE
			ELSE
				IF f.G.ShowNext THEN
					ClearFig(f, NextXPos + 1, NextYPos + 1, fig, 0);
					DrawFig(f, NextXPos + 1, NextYPos + 1, next, 0)
				END;
				DrawFig(f, x, y, fig, p)
			END
		END;

		DelCount := 0;
		WHILE ~done & (DelCount < f.G.Delay) DO
			IF Input.Available() > 0 THEN
				Input.Read(c);
				IF (c = ch[5]) OR (c = "P") OR (c = "p") THEN done := TRUE
				ELSIF c = ch[0] THEN								(* left *)
					IF TestFig(f.G, x - 1, y, fig, p) THEN
						ClearFig(f, x, y, fig, p);
						DEC(x);
						DrawFig(f, x, y, fig, p)
					END
				ELSIF c = ch[1] THEN								(* right *)
					IF TestFig(f.G, x + 1, y, fig, p) THEN
						ClearFig(f, x, y, fig, p);
						INC(x);
						DrawFig(f, x, y, fig, p)
					END
				ELSIF (c = ch[2]) & (x # -1) THEN		(* flipleft *)
					d := p + 1; IF d = 4 THEN d := 0 END;
					IF TestFig(f.G, x, y, fig, d) THEN
						ClearFig(f, x, y, fig, p);
						DrawFig(f, x, y, fig, d);
						p := d
					END
				ELSIF (c = ch[3]) & (x # -1) THEN		(* flipright *)
					d := p - 1; IF d = -1 THEN d := 3 END;
					IF TestFig(f.G, x, y, fig, d) THEN
						ClearFig(f, x, y, fig, p);
						DrawFig(f, x, y, fig, d);
						p := d
					END
				ELSIF c = ch[4] THEN							  (* down *)
					d := y;
					WHILE TestFig(f.G, x, y - 1, fig, p) DO DEC(y) END;
					ClearFig(f, x, d, fig, p);
					DrawFig(f, x, y, fig, p)
				END
			END;
			INC(DelCount)
		END
	UNTIL done;

	IF f.G.Runs THEN
		f.G.x := x;  f.G.y := y;  f.G.p := p;  f.G.fig := fig;  f.G.next := next;
		Texts.WriteString(W, "Current ObTris Status -")
	ELSE
		Texts.WriteString(W, "--- GAME OVER ---   ");
		RegisterScore(f.G.Score, f.G.Level, f.G.Lines);
		gameOver := TRUE
	END;
	IF gameOver & (HiRank > 0) THEN Texts.WriteString(W, " Ranking: "); Texts.WriteInt(W, HiRank, 0) END;
	Texts.WriteString(W, "  Score: ");
	Texts.WriteInt(W, f.G.Score * ScoreFakt, 1);
	Texts.WriteString(W, "  Lines: ");
	Texts.WriteInt(W, f.G.Lines, 1);
	Texts.WriteString(W, "  Level: ");
	Texts.WriteInt(W, f.G.Level, 1);
	Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf);
	msg.G := f.G;  Viewers.Broadcast(msg)

END GameLoop;


(* Start New Game *)
PROCEDURE StartNewGame(g: Frame);
	VAR msg: DrawMsg;
BEGIN
	IF g.Aktiv THEN
		g.G.Delay := Delay;
		ClearField(g.G);
		g.G.y := YAnzahl - 2;  g.G.p := 0;  g.G.fig := Random(7);  g.G.next := Random(7);
		g.G.Lines := 0;  g.G.Score := 0;  g.G.Level := 0;  g.G.x := ((XAnzahl - FigSize[g.G.fig]) DIV 2) + 1;
		IF g.G.fig = 1 THEN DEC(g.G.y); g.G.p := 2 END;
		msg.G := g.G;  Viewers.Broadcast(msg);
		GameLoop(g)
	END
END StartNewGame;


(* Open new ObTris Frame *)
PROCEDURE Open*;
	VAR
		f: Frame;
		v: MenuViewers.Viewer;
		x, y: INTEGER;
BEGIN
	NEW(f);  NEW(f.G);  f.G.ShowNext := TRUE;  f.Aktiv := FALSE;
	f.handle := Handler;
	Oberon.AllocateUserViewer(Oberon.Par.vwr.X, x, y);
	v := MenuViewers.New(MenuFrame(), f, TextFrames.menuH, x, y);
	ClearField(f.G);
END Open;


(* Start New Game Command *)
PROCEDURE StartNew*;
	VAR f, g: Display.Frame;
BEGIN
	IF GetFrame(f) THEN
		StartNewGame(f(Frame))
	END
END StartNew;


(* Restart Game or Start New *)
PROCEDURE Start*;
	VAR f: Display.Frame; g: Frame;
BEGIN
	IF GetFrame(f) THEN
		g := f(Frame);
		IF g.Aktiv THEN
			IF g.G.Runs THEN 
				GameLoop(g)
			ELSE					
				StartNewGame(g)
			END
		END
	END
END Start;


(* Show next-figure toggle *)
PROCEDURE ShowNext*;
	VAR
		f: Display.Frame; g: Frame;
		msg: DrawMsg;
BEGIN
	IF GetFrame(f) THEN
		g := f(Frame);
		g.G.ShowNext := ~g.G.ShowNext;
		msg.G := g.G; Viewers.Broadcast(msg)
	END
END ShowNext;


(* set new username *)
PROCEDURE SetUser*;
	VAR
		S: Texts.Scanner;
		text: Texts.Text;
		beg, end, time: LONGINT;
		error: BOOLEAN;
BEGIN
	error := FALSE; Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(S);
	IF S.class = Texts.Char THEN
		IF S.c # "^" THEN error := TRUE
		ELSE
			Oberon.GetSelection(text, beg, end, time);
			IF time = -1 THEN error := TRUE
			ELSE
				Texts.OpenScanner(S, text, beg);
				Texts.Scan(S)
			END
		END
	END;
	IF ~error & (S.class = Texts.Name) THEN
		Strings.Copy(S.s, Name)
	END;
	Texts.WriteString(W, "Current Username: "); Texts.WriteString(W, Name); Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf)
END SetUser;


(* Decode and write a date packed by module Kernel in a 32-bit date+time encoding. See PO.System.pdf p. 110 *)
PROCEDURE WriteDate (VAR W: Texts.Writer; dt: INTEGER);

	PROCEDURE WritePair (VAR W: Texts.Writer; x: INTEGER);
	(* Convert an integer < 100 to two characters *)
	BEGIN
		Texts.Write(W, CHR(x DIV 10 + 30H));    (* first digit *)
		Texts.Write(W, CHR(x MOD 10 + 30H))  (* second digit *)
	END WritePair;

BEGIN
	Texts.WriteString(W, "");       WritePair(W, dt DIV 20000H MOD 20H);     (* day *)
	Texts.WriteString(W, "-");     WritePair(W, dt DIV 400000H MOD 10H);   (* month *)
	Texts.WriteString(W, "-20"); WritePair(W, dt DIV 4000000H MOD 40H)  (* year *)
END WriteDate;


(* show Hi-Score *)
PROCEDURE Score*;
	VAR
		i: INTEGER;
		te: Texts.Text;
BEGIN
(* NEW(te); te := TextFrames.Text(""); *)
	IF Files.Old("ObTris_Score.Text") = NIL THEN
		NEW(te); te := TextFrames.Text("");

		Texts.SetFont(W, Fonts.This("Courier10.Fnt"));

		Texts.WriteString(W, " Oberon-Tetris Hall Of Fame !   "); Texts.WriteLn(W);
		Texts.WriteString(W, "-------------------------------------------"); Texts.WriteLn(W)
	ELSE
		Texts.Open(te, "ObTris_Score.Text");
	END;

	FOR i := 0 TO 9 DO
		IF HiScore[i] > 0 THEN
			Texts.WriteInt(W, i + 1, 2);                               Texts.WriteString(W, ".  ");
			Texts.WriteString(W, HiName[i]);
			Texts.WriteInt(W, HiScore[i] * ScoreFakt, 7);  Texts.WriteString(W, "   ");
			Texts.WriteInt(W, HiLines[i], 3);                       Texts.WriteString(W, "   ");
			Texts.WriteInt(W, HiLevel[i], 2);                       Texts.WriteString(W, "   ");
			WriteDate(W, HiDateT[i]);
			Texts.WriteLn(W)
		END
	END;

	Texts.SetFont(W, Fonts.This("Oberon10.Scn.Fnt"));

	Texts.WriteLn(W);
	Texts.WriteString(W, "Current Username: ");
	Texts.WriteString(W, Name);
	Texts.WriteLn(W); Texts.WriteLn(W);
	PrintKeys();
	Texts.Append(te, W.buf);
	OpenViewer(te);
END Score;


(* set keys command *)
PROCEDURE SetKeys*;
	VAR
		S: Texts.Scanner;
		text: Texts.Text;
		d, beg, end, time: LONGINT;
		c: ARRAY 6 OF CHAR;
		error: BOOLEAN;
BEGIN
	error := FALSE;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(text, beg, end, time);
		IF time = -1 THEN error := TRUE
		ELSE
			Texts.OpenScanner(S, text, beg);
			Texts.Scan(S)
		END
	END;
	d := 0;
	WHILE ~error & (d < 6) DO
		IF (S.class = Texts.Char) & (S.c # 0X) THEN
			c[d] := S.c
		ELSIF (S.class = Texts.Int) & (S.i >= 0) & (S.i <= 9) THEN
			c[d] := CHR(48 + S.i)
		ELSIF S.class = Texts.Name THEN
			IF       S.s = "UP"        THEN c[d] := up
			ELSIF S.s = "DOWN" THEN c[d] := down
			ELSIF S.s = "LEFT"      THEN c[d] := left
			ELSIF S.s = "RIGHT"   THEN c[d] := right
			ELSIF S.s = "RETURN" THEN c[d] := 0DX
			ELSIF S.s = "TAB" THEN c[d] := 9X
			ELSIF S.s = "SPACE" THEN c[d] := 20X
			ELSIF S.s = "ESC" THEN c[d] := 1BX
			ELSE c[d] := S.s[0]
			END
		ELSE
			Texts.WriteString(W, "Wrong Key Or Not Enough Keys!");
			Texts.Append(Oberon.Log, W.buf); error := TRUE
		END;
		Texts.Scan(S);
		INC(d)
	END;
	IF ~error THEN
		FOR d := 0 TO 5 DO ch[d] := c[d] END;
		PrintKeys(); Texts.Append(Oberon.Log, W.buf);
		SaveHi(FALSE)
	END
END SetKeys;

(* Create all Figures in Fig *)
PROCEDURE CreateFigures;
	VAR a, p, x, y, s, d: INTEGER;

	PROCEDURE ClearFig (fi, neu: INTEGER);
		VAR x, y: INTEGER;
	BEGIN
		FOR x := 0 TO 3 DO
			FOR y := 0 TO 3 DO Fig[fi, neu,x, y] := 0 END
		END
	END ClearFig;

BEGIN
	(* clear all Figures at Pos 0*)
	FOR a := 0 TO 6 DO ClearFig(a, 0) END;

	(* set Figures at Pos 1*)
	FigSize[0] := 2;  Fig[0, 0, 0, 0] := blue;  Fig[0, 0, 1, 0] := blue;  Fig[0, 0, 0, 1] := blue;  Fig[0, 0, 1, 1] := blue;
	FigSize[1] := 4;  Fig[1, 0, 0, 1] := red;  Fig[1, 0, 1, 1] := red;  Fig[1, 0, 2, 1] := red;  Fig[1, 0, 3, 1] := red;
	FigSize[2] := 3;  Fig[2, 0, 1, 1] := green;  Fig[2, 0, 0, 0] := green;  Fig[2, 0, 1, 0] := green;  Fig[2, 0, 2, 1] := green;
	FigSize[3] := 3;  Fig[3, 0, 1, 1] := col1;  Fig[3, 0, 0, 1] := col1; Fig[3, 0, 1, 0] := col1;  Fig[3, 0, 2, 0] := col1;
	FigSize[4] := 3;  Fig[4, 0, 1, 1] := yellow;  Fig[4, 0, 0, 0] := yellow;  Fig[4, 0, 0, 1] := yellow;  Fig[4, 0, 2, 1] := yellow;
	FigSize[5] := 3;  Fig[5, 0, 1, 1] := col2;  Fig[5, 0, 2, 0] := col2; Fig [5, 0, 0, 1] := col2;  Fig[5, 0, 2, 1] := col2;
	FigSize[6] := 3;  Fig[6, 0, 1, 1] := col3;  Fig[6, 0, 1, 0] := col3;  Fig[6, 0, 0, 1] := col3;  Fig[6, 0, 2, 1] := col3;

	(* generate rotated Figures *)
	FOR a := 0 TO 6 DO
		FOR p := 1 TO 3 DO
			s := FigSize[a] - 1;
			IF (s = 1) OR (s = 2) THEN ClearFig(a, p); END;
			FOR x := 0 TO s DO
				FOR y := 0 TO s DO
					d := Fig[a, p-1, x, y];
					Fig[a, p, s-y, x] := d
				END
			END
		END
	END

END CreateFigures;


BEGIN
	Texts.OpenWriter(W);
	Texts.WriteString(W, "ObTris (Oberon-Tetris) V1.0");
	Texts.WriteLn(W);
	Texts.WriteString(W, "(c) 1 Nov 1995 by Ralf Degner");
	Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf);

	IF Oberon.User = "" THEN 
		Name := "AMIGA"
(* ELSE 
		COPY(Oberon.User, Name) *)  (* original by Ralph Degner *)
(* ELSE 
		Name := Oberon.User *)  (* "illegal assignment" *)
(* ELSE							  	
		Name := "";  Strings.Insert(Name, 0, Oberon.User); *)  (* Joerg Straube *)
(* ELSE						  		
		Name := "";  Strings.Insert(Oberon.User, 0, Name); *)  (* hk, Oakwood version *)
	ELSE                                  
		Strings.Copy(Oberon.User, Name);  (* hk *)
	END;

	Delay := CalcSysSpeed();
	CreateFigures();
	LoadHi();  (* load the data of the high score file into main memory *)
END ObTris.


ORP.Compile ObTris.Mod/s ~
System.Free ObTris ~
System.Open ObTris.Tool

