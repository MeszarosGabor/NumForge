import 'package:flutter/material.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const cBg     = Color(0xFF111118);
const cTarget = Color(0xFFF2C14E);
const cNumber = Color(0xFF3470CC);
const cSelA   = Color(0xFFE5831A);
const cSelB   = Color(0xFF9933CC);
const cOp     = Color(0xFF22816A);
const cOpSel  = Color(0xFF3DCCAA);
const cDim    = Color(0xFF666666);
const cWin    = Color(0xFF33CC66);
const cLose   = Color(0xFFCC4444);
const cText   = Colors.white;

const levelColors = {
  3: Color(0xFF33CC66),
  4: Color(0xFF3DCCAA),
  5: Color(0xFFE5831A),
  6: Color(0xFFCC4444),
};

// ── Gameplay ──────────────────────────────────────────────────────────────────

const initHints      = 6;
const puzzleRetries  = 3;
const nextLevelDelay = Duration(seconds: 2);

// ── Bubble sizes ──────────────────────────────────────────────────────────────

const targetBubbleSize  = 88.0;
const numberBubbleSize  = 68.0;
const opBtnSize         = 68.0;
const iconBtnSize       = 52.0;
const orbitRadiusFrac   = 0.30;

// ── Font sizes ────────────────────────────────────────────────────────────────

const targetFontSize = 26.0;
const numberFontSize = 22.0;
const opFontSize     = 28.0;
const streakFontSize = 28.0;
const iconFontSize   = 22.0;
const iconIconSize   = 26.0;

// ── Layout ────────────────────────────────────────────────────────────────────

const opBtnPad          = 18.0;
const opBtnTopOffset    = 48.0;
const bottomCtrlPad     = 16.0;
const statusLineFrac    = 0.14;
const streakTopOffset   = 52.0;   // padding.top + opBtnTopOffset + 4
const titleCenterOffset = 80.0;   // cy - titleCenterOffset

// ── Menu buttons (PLAY / STREAKS) ─────────────────────────────────────────────

const menuBtnWidth   = 140.0;
const menuBtnHeight  = 56.0;
const menuBtnRadius  = 28.0;
const menuBtnPadBot  = 48.0;

// ── Splash animation ──────────────────────────────────────────────────────────

const splashFadeDuration = Duration(milliseconds: 900);

// ── Level select screen ───────────────────────────────────────────────────────

const levelSelectHPad    = 48.0;
const levelSelectSpacing = 24.0;
const levelSelectRadius  = 24.0;
const levelNumFontSize   = 42.0;
const levelLabelFontSize = 14.0;

// ── Streaks screen ────────────────────────────────────────────────────────────

const streakDotSize      = 20.0;
const streakScreenFont   = 48.0;
const streakLabelFont    = 22.0;
