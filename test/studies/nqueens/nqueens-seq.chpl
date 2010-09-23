// A backtracking solver for the N Queens problem.
// This is a sequential version of the parallel solver in queens-par.chpl.

/////////////////////////////////////////////////////////////////////////////
// the data structure
//
// Maintains the placement of the queens.
// Only chess-legal placements are stored.
//
// Provides efficient updates in-place (we expect this to be useful).
//
// Queens must be placed in consecutive rows, starting at row 1.
// Queens must be removed in the LIFO order.
//
class Board {

  // size of the board
  const boardSize: int;

  // queenvec(row) is the column the queen is at, 0 if none
  var queenvec: [1..boardSize] int;

  // the largest row that has been filled in, 0 if none
  var lastfilled: int = 0;

}  // class Board

//
// Public interface.
// Create an empty board of the given size.
// NB could not do this by writing our own constructor.
//
def createBoard(boardSize:int) {
  return new Board(boardSize = boardSize);
}

//
// Public interface.
// If placing a queen at (row,col) is legal, do so and return true.
// Otherwise, don't and return false.
//
def Board.placeNextIfLegal(row: int, col: int): bool {
  debug("adding   ", row, ", ", col);
  if !(lastfilled < boardSize) then
    halt("attempting to add a queen past the board's capacity");
  if !(1 <= col && col <= boardSize) then
    halt("illegal column: ", col, " attempted to be added at row ", row);
  if !(row == lastfilled + 1) then
    halt("the next queen must be placed in row ", lastfilled + 1,
         ", attempted to place it in row ", row);

  if !(queenvec(row) == 0) then
    halt("there is already a queen at row ", row,
	 " (column ", queenvec(row), ")");

  if nextPlacementIsLegal(row, col) then {
    queenvec(row) = col;
    lastfilled += 1;
    return true;
  } else {
    return false;
  }
}

//
// Public interface.
// Remove a queen in the LIFO order.
//
def Board.removeLast(row: int, col: int): void {
  debug("removing ", row, ", ", col, "\n");
  if !(row == lastfilled) then
    halt("attempted to remove a queen in a non-LIFO order",
         " from row ", row, ", should be row ", lastfilled);
  if !(queenvec(row) == col) then
    halt("attempted to remove a queen at row ", row,
         " from column ", col, ", should be column ", queenvec(row));

  queenvec(row) = 0;
  lastfilled -= 1;
}

//
// Private helper: would the proposed placement be legal?
// Assume the existing placement is legal.
//
def Board.nextPlacementIsLegal(row: int, col: int): bool {
  for i in 1..lastfilled {
    if
      queenvec(i) == col ||
      queenvec(i) - col == i - row ||
      queenvec(i) - col == row - i
    then {
      // it's illegal, quit
      debug("  conflict: ", i, ", ", queenvec(i), " vs ", row, ", ", col, "\n");
      return false;
    }
  }

  // everything is hunky-dory
  debug("  legal\n");
  return true;
}

//
// Display the board.
//
config var show1line: bool = true;

def Board.show(msg...): void {
  if boardSize <= 0 then {
    writeln("the board is empty", (...msg));
    return;
  }
  var notFilledMsg = "";
  if lastfilled < boardSize then notFilledMsg =
    " row(s) "+ (lastfilled + 1) + " to " + boardSize + " are not filled";
  if show1line then {
    writeln(
            [row in 1..lastfilled] (row, queenvec(row)),
            notFilledMsg, (...msg));
  } else {
    for [1..boardSize] do write("-"); writeln((...msg));
    for row in 1..lastfilled {
      for col in 1..boardSize do
        write(if queenvec(row) == col then "*" else " ");
      writeln();
    }
    if notFilledMsg != "" then writeln(notFilledMsg);
    for [1..boardSize] do write("-"); writeln();
  }
}

/////////////////////////////////////////////////////////////////////////////
// debugging support

// show debugging info?
config var dbg: bool = false;
def debug(arg...)  { if dbg  then write((...arg)); }

/////////////////////////////////////////////////////////////////////////////
// the algorithm

// ancillary: count the solutions
var solutionCount: int;

//
// Given a partially-filled board, we try placing a queen
// in the next row - trying each column in turn.
// If the column succeeds, we proceed to the next row
// (or show the result if we have filled all rows).
//
def tryQueenInNextRow(board: Board): void {
  // the row we will be placing in
  var nextRow = board.lastfilled + 1;

  // iterate over the columns
  for col in 1..board.boardSize {
    // place the queen in that column if legal
    if board.placeNextIfLegal(nextRow, col) then {
      if nextRow == board.boardSize then {
        // found a complete solution
        solutionCount += 1;
        board.show("");
      } else {
        tryQueenInNextRow(board);
      }
      // remove the placed queen so we can try another column
      // (this is merely to satisfy our assertions)
      board.removeLast(nextRow, col);
    }
  }
}  // tryQueenInNextRow

/////////////////////////////////////////////////////////////////////////////
// the driver

// how big the board to play
config const N = 8;

//
// The main program.
//
def main() {
  solutionCount = 0;
  writeln("Solving N Queens for N=", N, "...");
  tryQueenInNextRow(createBoard(N));   // elide dealloc of this board
  writeln("Found ", solutionCount, " solutions for N=", N);
}
