//
// Block Distribution
// 
//      Block       BlockDom     BlockArr
//
//   LocBlock    LocBlockDom  LocBlockArr
//

use DSIUtil;
use IO;
use Time;


//
// TODO List
//
// 1. Make multi-dimensional
// 2. Support strided domains of locales
// 3. Support strided Block domains
// 4. Support slices
//
// Limitations
//
// 1. Changes to Block.tasksPerLocale are not made in privatized
//    copies of this distribution.
//


config param debugDistDistIO = true; // internal development flag (debugging)
config param debugDefaultDistIOBulkTransfer = false; // internal development flag (debugging)
config param debugDistIOBulkTransfer = false; // internal development flag (debugging)


////////////////////////////////////////////////////////////////////////////////
// DistIO Distribution Class
//
class DistIO : BaseDist {
  param rank: int;
  type idxType = int;

  const lowIdx: rank*idxType;
  const blocksize: rank*int;
  const targetLocDom: domain(rank);
  const targetLocales: [targetLocDom] locale;
  const locDist: [targetLocDom] LocDistIO(rank, idxType);

  var tasksPerLocale: int; // tasks per locale for forall iteration

  proc DistIO(startIdx,  // ?nd*?idxType
                   blocksize,     // nd*int
                   targetLocales: [] locale = Locales, 
                   tasksPerLocale = 0,
                   param rank = startIdx.size,
                   type idxType = startIdx(1).type) {
    this.lowIdx = startIdx;
    this.blocksize = blocksize;
    if rank == 1 {
      targetLocDom = [0..#targetLocales.numElements]; // 0-based for simplicity
      this.targetLocales = targetLocales;
    } else if targetLocales.rank == 1 then {

      // BLC: Common code, factor out

      const factors = _factor(rank, targetLocales.numElements);
      var ranges: rank*range;
      for param i in 1..rank do
        ranges(i) = 0..factors(i)-1;
      targetLocDom = [(...ranges)];
      for (loc1, loc2) in (this.targetLocales, targetLocales) do
        loc1 = loc2;
      if debugDistDistIO {
        writeln(targetLocDom);
        writeln(this.targetLocales);
      }
    } else {
      if targetLocales.rank != rank then
	compilerError("locales array rank must be one or match distribution rank");

      var ranges: rank*range;
      for param i in 1..rank do {
	var thisRange = targetLocales.domain.dim(i);
	ranges(i) = 0..#thisRange.length; 
      }
      
      targetLocDom = [(...ranges)];
      if debugDistDistIO then writeln(targetLocDom);

      this.targetLocales = reshape(targetLocales, targetLocDom);
      if debugDistDistIO then writeln(this.targetLocales);
    }

    coforall locid in targetLocDom do
      on this.targetLocales(locid) do
        locDist(locid) = new LocDistIO(rank, idxType, locid, this);

    if tasksPerLocale == 0 then
      this.tasksPerLocale = 1;   // TODO: here.numCores;
    else
      this.tasksPerLocale = tasksPerLocale;

    if debugDistDistIO then
      for loc in locDist do writeln(loc);
  }

  // copy constructor for privatization
  proc DistIO(param rank: int, type idxType, other: DistIO(rank, idxType)) {
    lowIdx = other.lowIdx;
    blocksize = other.blocksize;
    targetLocDom = other.targetLocDom;
    targetLocales = other.targetLocales;
    locDist = other.locDist;
    tasksPerLocale = other.tasksPerLocale;
  }

  proc dsiClone() {
    return new DistIO(lowIdx, blocksize, targetLocales, tasksPerLocale);
  }
}

//
// create a new rectangular domain over this distribution
//
proc DistIO.dsiNewRectangularDom(param rank: int, type idxType,
                           param stridable: bool) {
  if idxType != this.idxType then
    compilerError("DistIO domain index type does not match distribution's");
  if rank != this.rank then
    compilerError("DistIO domain rank does not match distribution's");

  var dom = new DistIODom(rank=rank, idxType=idxType, dist=this, stridable=stridable);
  dom.setup();
  return dom;
}

//proc DistIO.dsiSupportsBulkTransfer() param return true;


proc DistIOArr.doiCanIO() {return true;}
proc DistIOArr.dsiSupportIORead() {return true;}
proc DistIOArr.dsiSupportIOWrite() {return true;}

proc DistIOArr.doiCanBulkTransferStride() {
	  if debugDefaultDistBulkTransfer then writeln("In BlockArr.doiCanBulkTransfer");
	  //if dom.stridable then
	  //  if disableAliasedBulkTransfer then
	  //writeln("_arrAlias: ",_arrAlias);

	    //if _arrAlias != nil then return false;
	    
	  writeln("DistIO doiCanBulkTransfer TRUE!");
	    return true;
}


proc DistIO.doiCanBulkTransfer() {
	  writeln("In BlockArr.doiCanBulkTransfer");
	  if debugDefaultDistIOBulkTransfer then writeln("In BlockArr.doiCanBulkTransfer");

//	    if dom.stridable then
//		        for param i in 1..rank do
//				      if dom.whole.dim(i).stride != 1 then return false;

	      // See above note regarding aliased arrays

// if disableAliasedBulkTransfer then
//		          if _arrAlias != nil then return false;

	        return true;
}

proc DistIOArr.doIORead(B) {
	  writeln("In DistIOArr.doRead");
	 if debugDistDistIO then writeln("---------To Read B: ",B,"----------------");
	  var infile = open(_filename, iomode.r);
	  var ch = infile.reader(style=defaultIOStyle().native());
	  for b in B do {
		ch.read(b);
//		writeln("element ",b," read");
	  }
	  ch.close();
}
	

proc DistIOArr.doIOWrite(B) {
	var fn=getFilename();
//	if debugDistDistIO then  writeln("---------To Write B: ",B,"------- to file:",fn,"---------");
			var of = open(fn, iomode.rw);
			var chan = of.writer(style=defaultIOStyle().native());
			chan.close();
	writeln("In DistIOArr.doIOWrite");
//	coforall i in dom.dist.targetLocDom do
	// 
	var num_oss=4:int;
				var stride=dom.dist.blocksize;
        coforall i in 0..num_oss-1 do on  Locales(i%numLocales) do {
		writeln("Ahora estamos aqui:",here.id);
//	for i in dom.dist.targetLocDom do
//		on dom.dist.targetLocales(i)  {
		
			if debugDistIOBulkTransfer then startCommDiagnosticsHere();
			if rank ==1
			{
				var stripe_size=stride(1):int;
				var locBuff:[0..(stripe_size-1)] int;
				
				var high=dom.dsiDim(1).high;
				//var low=dom.dsiDim(1).low;
				var low=dom.dsiDim(1).low+stripe_size*i;
				var init=0-dom.dsiDim(1).low;
				//var stride=dom.dsiDim(1).stride;

	writeln("In DistIOArr.doIOWrite locale:",i," low:",low," high:",high," stride:",stride(1));
				for from in low..high by stripe_size*num_oss {
	//			for el in Arr[i] {
					/*


			//var ch = outfile.writer(style=defaultIOStyle().native());
			var lo = dom.locDoms[i].myStarts.low-1;
			var total = dom.locDoms[i].myStarts.numIndices-1;
			*/
/*			writeln("i:",i," start:",4*lo," end:",4*lo+4*total,"  myStarts:", dom.locDoms[i].myStarts);
			writeln(" myFlatInds:", dom.locDoms[i].myFlatInds);
			writeln(" myElems:", locArr[i].myElems);
*/
			//var ch = outfile.writer(native,start=4*lo,end=4*lo+4*total);
			var outfile = open(fn, iomode.rw);
			var to=from+stripe_size-1;
			if ( to > high ) then to=high;
			var ch = outfile.writer(style=defaultIOStyle().native(),start=(init+from)*8,end=(init+to+1)*8);
	writeln("channel inside from :",(init+from)*8," to :",(init+to)*8);
	writeln("channel inside from :",from," to :",to," range:",to-from);
			var first: bool = true;
		//	for e in dom.locDoms[i].myStarts {
			
			
	//		locBuff=this.dsiSlice([from..from+stripe_size]);
			var uuu=to-from;
//			locBuff[0..uuu]=B[from..to];
			locBuff[0..uuu]=B[from..to];

			
			for e in locBuff[0..uuu] {
				/*
				if debugDistDistIO then	 {
					if !first then
						write(" ");
					else 
						first = false;
					write(e);
				}
				writeln("element ",e," to be written");
*/				ch.write(e);
			}
			writeln("");
			ch.flush();
			ch.close();
//			sleep(5);
				} // closes for by loop
			} else writeln("rank not supported");
		}
//	}


}

proc DistIOArr.getFilename() :string {
	writeln("filename is :",_filename);
	return _filename;
}

proc DistIOArr.setFilename(fn) {
	_filename=fn;
	writeln("filename set to :",_filename);
}

proc DistIOArr.doiBulkTransfer(B) {
/*
	if debugDistIOBulkTransfer{ writeln("In BlockArr.doiBulkTransferStride.");resetCommDiagnostics();}
	coforall i in dom.dist.targetLocDom do
		on dom.dist.targetLocales(i)  {
			if debugDistIOBulkTransfer then startCommDiagnosticsHere();

			var total = dom.locDoms[i].myBlock.numIndices;
			var lo = dom.locDoms[i].myBlock.low;
			var lo_ini = lo;
			const offset   = B._value.dom.whole.low - dom.whole.low;
		}

	
	  writeln("In DistIOArr.doiBulkTransfer");
	if debugDistDistIO then  writeln("---------To transfer B: ",B,"----------------");
	  var outfile = open("test1.bor", iomode.cwr);
	  var ch = outfile.writer(style=defaultIOStyle().native());
	  for b in B do {
		ch.write(b:int);
	if debugDistDistIO then	writeln("element ",b," written");
	  }
	  ch.close();

	if debugDistIOBulkTransfer then stopCommDiagnosticsHere();
	if debugDistIOBulkTransfer then writeln("Comms:",getCommDiagnostics());

*/

}
//
// output distribution
//
proc DistIO.writeThis(x:Writer) {
  x.writeln("DistIO");
  x.writeln("-------");
  x.writeln("distributes: ", lowIdx, "...");
  x.writeln("in chunks of: ", blocksize);
  x.writeln("across locales: ", targetLocales);
  x.writeln("indexed via: ", targetLocDom);
  x.writeln("resulting in: ");
  for locid in targetLocDom do
    x.writeln("  [", locid, "] ", locDist(locid));
}

//
// convert an index into a locale value
//
proc DistIO.dsiIndexToLocale(ind: idxType) where rank == 1 {
  return targetLocales(idxToLocaleInd(ind));
}

proc DistIO.dsiIndexToLocale(ind: rank*idxType) {
  return targetLocales(idxToLocaleInd(ind));
}

//
// compute what chunk of inds is owned by a given locale -- assumes
// it's being called on the locale in question
//
proc DistIO.getStarts(inds, locid) {
  // use domain slicing to get the intersection between what the
  // locale owns and the domain's index set
  //
  // TODO: Should this be able to be written as myChunk[inds] ???
  //
  // TODO: Does using David's detupling trick work here?
  //
  var D: domain(rank, idxType, stridable=true);
  var R: rank*range(idxType, stridable=true);
  for i in 1..rank {
    var lo, hi: idxType;
    const domlo = inds.dim(i).low, 
          domhi = inds.dim(i).high;
    const mylo = locDist(locid).myStarts(i).low;
    const mystr = locDist(locid).myStarts(i).stride;
    if (domlo != lowIdx(i)) {
      if (domlo <= domhi) {
        if (domlo > lowIdx(i)) {
	  const off = (domlo - mylo)%mystr;
	  if (off == 0) {
	    lo = domlo;
	    hi = domhi;
	  } else {
	    lo = domlo-off;
	    hi = domhi;
//	    halt("BLC: need to handle unaligned low");
	  }
	} else {
	  halt("BLC: need to handle domain low less than lowIdx");
        }	  
      } else {
        lo = domlo;
        hi = domhi;
      }
    } else {
      lo = mylo;
      hi = domhi;
    }
    R(i) = lo..hi by mystr;
  }
  D.setIndices(R);
  return D;
}

//
// determine which locale owns a particular index
//
// TODO: I jotted down a note during the code review asking whether
// targetLocales.numElements and boundingbox.numIndices should be
// captured locally, or captured in the default dom/array implementation
// or inlined.  Not sure what that point was anymore, though.  Maybe
// someone else can help me remember it (since it was probably someone
// else's suggestion).
//
proc DistIO.idxToLocaleInd(ind: idxType) where rank == 1 {
  const ind0 = ind - lowIdx(1);
  //  compilerError(typeToString((ind0/blocksize(1)%targetLocDom.dim(1).type));
  return (ind0 / blocksize(1)) % targetLocDom.dim(1).length;
}

proc DistIO.idxToLocaleInd(ind: rank*idxType) where rank == 1 {
  return idxToLocaleInd(ind(1));
}

proc DistIO.idxToLocaleInd(ind: rank*idxType) where rank != 1 {
  var locInd: rank*int;
  for param i in 1..rank {
    const ind0 = ind(i) - lowIdx(i);
    locInd(i) = ((ind0 / blocksize(i)) % targetLocDom.dim(i).length): int; 
  }
  return locInd;
}

////////////////////////////////////////////////////////////////////////////////
// DistIO Local Distribution Class
//
class LocDistIO {
  param rank: int;
  type idxType;

  //
  // This stores the piece of the global bounding box owned by
  // the locale.  Note that my original guess that we'd want
  // to use lclIdxType here is wrong since we're talking about
  // the section of the global index space owned by the locale.
  //
  const myStarts: rank*range(idxType, BoundedRangeType.boundedLow, stridable=true);

  //
  // Constructor computes what chunk of index(1) is owned by the
  // current locale
  //
  proc LocDistIO(param rank: int,
                 type idxType, 
                 locid,   // the locale index from the target domain
                 dist: DistIO(rank, idxType)) { // reference to glob dist
    if rank == 1 {
      const lo = dist.lowIdx(1) + (locid * dist.blocksize(1));
      const str = dist.blocksize(1) * dist.targetLocDom.numIndices;
      myStarts(1) = lo.. by str;
    } else {
      for param i in 1..rank {
        const lo = dist.lowIdx(i) + (locid(i) * dist.blocksize(i));
        const str = dist.blocksize(i) * dist.targetLocDom.dim(i).length;
        myStarts(i) = lo.. by str;
      }
    }
  }
}


proc LocDistIO.writeThis(x:Writer) {
  var localeid: int;
  on this {
    localeid = here.id;
  }
  x.write("locale ", localeid, " owns blocks: ", myStarts);
}

////////////////////////////////////////////////////////////////////////////////
// DistIO Domain Class
//
class DistIODom: BaseRectangularDom {
  param rank: int;
  type idxType;
  param stridable: bool;
  //
  // LEFT LINK: a pointer to the parent distribution
  //
  const dist: DistIO(rank, idxType);

  //
  // DOWN LINK: an array of local domain class descriptors -- set up in
  // setup() below
  //
  var locDoms: [dist.targetLocDom] LocDistIODom(rank, idxType, stridable);

  //
  // a domain describing the complete domain
  //
  const whole: domain(rank=rank, idxType=idxType, stridable=stridable);
  //  const startLoc: index(dist.targetLocDom);

  var pid: int = -1; // privatized object id
}

proc DistIODom.dsiDims() return whole.dims();

proc DistIODom.dsiDim(d: int) return whole.dim(d);

iter DistIODom.these() {
  for i in whole do
    yield i;
}

iter DistIODom.these(param tag: iterKind) where tag == iterKind.leader {
  const precomputedNumTasks = dist.tasksPerLocale;
  const precomputedWholeLow = whole.low;
  if (precomputedNumTasks != 1) then
    halt("Can't use more than one task per locale with Block-Cyclic currently");
  coforall locDom in locDoms do on locDom {
      var tmpblock:rank*range(idxType, stridable=stridable);
    for i in locDom.myStarts {
	    // TODO Rafael
            writeln("debug INFO [", here.id, "] starting at ", i);
      for param j in 1..rank {
        // TODO: support a tuple-oriented iteration of vectors to avoid this?
        var lo: idxType;
        if rank == 1 then
          lo = i;
        else
          lo = i(j);
        tmpblock(j) = max(lo, whole.dim(j).low)..
	              min(lo + dist.blocksize(j)-1, whole.dim(j).high);
        //        writeln("[", here.id, "] tmpblock(j) = ", tmpblock(j));
        tmpblock(j) = whole.dim(j)[tmpblock(j)];
        //        writeln("[", here.id, "] tmpblock(j) = ", tmpblock(j));
        if rank == 1 then
          lo = whole.low;
        else
          lo = whole.low(j);
        //        writeln("lo = ", lo);
        tmpblock(j) = tmpblock(j).chpl__unTranslate(lo);
        //        writeln("[", here.id, "] tmpblock(j) = ", tmpblock(j));
      }

      var retblock: rank*range(idxType);
      for param i in 1..rank {
        retblock(i) = (tmpblock(i).low / whole.dim(i).stride:idxType)..
                        #tmpblock(i).length;
          //        retblock(i) = (tmpblock(i) - whole.dim(i).low);
      }
      //      writeln(here.id, ": Domain leader yielding", retblock);
      yield retblock;
    }
  }
}

//proc DistIODom.isDistIO() param {return true;}

//
// TODO: Abstract the addition of low into a function?
// Note relationship between this operation and the
// order/position functions -- any chance for creating similar
// support? (esp. given how frequent this seems likely to be?)
//
// TODO: Is there some clever way to invoke the leader/follower
// iterator on the local blocks in here such that the per-core
// parallelism is expressed at that level?  Seems like a nice
// natural composition and might help with my fears about how
// stencil communication will be done on a per-locale basis.
//
iter DistIODom.these(param tag: iterKind, followThis) where tag == iterKind.follower {
  //  writeln(here.id, ": Domain follower following ", follower);
  var t: rank*range(idxType, stridable=stridable);
  for param i in 1..rank {
    var stride = whole.dim(i).stride: idxType;
    var low = stride * followThis(i).low;
    var high = stride * followThis(i).high;
    t(i) = (low..high by stride:int) + whole.dim(i).low;
  }
  //  writeln(here.id, ": Changed it into: ", t);
  for i in [(...t)] {
    yield i;
  }
}

//
// output domain
//
proc DistIODom.dsiSerialWrite(x:Writer) {
  x.write(whole);
}

//
// how to allocate a new array over this domain
//
proc DistIODom.dsiBuildArray(type eltType) {
  var arr = new DistIOArr(eltType=eltType, rank=rank, idxType=idxType, stridable=stridable, dom=this);
  arr.setup();
  return arr;
}

proc DistIODom.dsiNumIndices return whole.numIndices;
proc DistIODom.dsiLow return whole.low;
proc DistIODom.dsiHigh return whole.high;
proc DistIODom.dsiStride return whole.stride;

//
// INTERFACE NOTES: Could we make setIndices() for a rectangular
// domain take a domain rather than something else?
//
proc DistIODom.dsiSetIndices(x: domain) {
  if x.rank != rank then
    compilerError("rank mismatch in domain assignment");
  if x._value.idxType != idxType then
    compilerError("index type mismatch in domain assignment");
  whole = x;
  setup();
}

proc DistIODom.dsiSetIndices(x) {
  if x.size != rank then
    compilerError("rank mismatch in domain assignment");
  if x(1).idxType != idxType then
    compilerError("index type mismatch in domain assignment");
  //
  // TODO: This seems weird:
  //
  whole.setIndices(x);
  setup();
}

proc DistIODom.dsiGetIndices() {
  return whole.getIndices();
}

proc DistIODom.dsiMyDist() return dist;

proc DistIODom.setup() {
  coforall localeIdx in dist.targetLocDom do
    on dist.targetLocales(localeIdx) do
      if (locDoms(localeIdx) == nil) then
        locDoms(localeIdx) = new LocDistIODom(rank, idxType, stridable, this, 
                                                   dist.getStarts(whole, localeIdx));
      else {
        locDoms(localeIdx).myStarts = dist.getStarts(whole, localeIdx);
        locDoms(localeIdx).myFlatInds = [0..#locDoms(localeIdx).computeFlatInds()];
      }
  if debugDistDistIO then
    enumerateBlocks();
}

proc DistIODom.enumerateBlocks() {
  for locidx in dist.targetLocDom {
    on dist.targetLocales(locidx) do locDoms(locidx).enumerateBlocks();
  }
}

proc DistIODom.dsiSupportsPrivatization() param return true;

proc DistIODom.dsiGetPrivatizeData() return 0;

proc DistIODom.dsiPrivatize(privatizeData) {
  var privateDist = new DistIO(rank, idxType, dist);
  var c = new DistIODom(rank=rank, idxType=idxType, stridable=stridable, dist=privateDist);
  c.locDoms = locDoms;
  c.whole = whole;
  return c;
}

proc DistIODom.dsiGetReprivatizeData() return 0;

proc DistIODom.dsiReprivatize(other, reprivatizeData) {
  locDoms = other.locDoms;
  whole = other.whole;
}

proc DistIODom.dsiMember(i) {
  return whole.member(i);
}

proc DistIODom.dsiIndexOrder(i) {
  return whole.indexOrder(i);
}

proc DistIODom.dsiBuildRectangularDom(param rank: int, type idxType,
                                         param stridable: bool,
                                         ranges: rank*range(idxType,
                                                            BoundedRangeType.bounded,
                                                            stridable)) {
  if idxType != dist.idxType then
    compilerError("DistIO domain index type does not match distribution's");
  if rank != dist.rank then
    compilerError("DistIO domain rank does not match distribution's");

  var dom = new DistIODom(rank=rank, idxType=idxType,
                               dist=dist, stridable=stridable);
  dom.dsiSetIndices(ranges);
  return dom;
}


////////////////////////////////////////////////////////////////////////////////
// DistIO Local Domain Class
//
class LocDistIODom {
  param rank: int;
  type idxType;
  param stridable: bool;

  //
  // UP LINK: a reference to the parent global domain class
  //
  const globDom: DistIODom(rank, idxType, stridable);

  //
  // a local domain describing the indices owned by this locale
  //
  // NOTE: I used to use a local index type for this, but that would
  // require a glbIdxType offset in order to get from the global
  // indices back to the local index type.
  //
  var myStarts: domain(rank, idxType, stridable=true);
  var myFlatInds: domain(1) = [0..#computeFlatInds()];
}

//
// Initialization helpers
//
proc LocDistIODom.computeFlatInds() {
  //  writeln("myStarts = ", myStarts);
  const numBlocks = * reduce [d in 1..rank] (myStarts.dim(d).length),
    indsPerBlk = * reduce [d in 1..rank] (globDom.dist.blocksize(d));
  //  writeln("Total number of inds = ", numBlocks * indsPerBlk);
  return numBlocks * indsPerBlk;
}

//
// output local domain piece
//
proc LocDistIODom.writeThis(x:Writer) {
  x.write(myStarts);
}

proc LocDistIODom.enumerateBlocks() {
  for i in myStarts {
    write(here.id, ": [");
    for param j in 1..rank {
      if (j != 1) {
        write(", ");
      }
      // TODO: support a tuple-oriented iteration of vectors to avoid this?
      var lo: idxType;
      if rank == 1 then
        lo = i;
      else
        lo = i(j);
      write(lo, "..", min(lo + globDom.dist.blocksize(j)-1, 
                          globDom.whole.dim(j).high));
    }
    writeln("]");
  } 
}
  

//
// queries for this locale's number of indices, low, and high bounds
//
// TODO: I believe these are only used by the random number generator
// in stream -- will they always be required once that is rewritten?
//
proc LocDistIODom.numIndices {
  return myStarts.numIndices;
}

proc LocDistIODom.low {
  return myStarts.low;
}

proc LocDistIODom.high {
  return myStarts.high;
}

////////////////////////////////////////////////////////////////////////////////
// DistIO Array Class
//
class DistIOArr: BaseArr {
  type eltType;
  param rank: int;
  type idxType;
  param stridable: bool;

  //
  // LEFT LINK: the global domain descriptor for this array
  //
  var dom: DistIODom(rank, idxType, stridable);

  //
  // DOWN LINK: an array of local array classes
  //
  var locArr: [dom.dist.targetLocDom] LocDistIOArr(eltType, rank, idxType, stridable);

  //
  // optimized reference to a local LocDistIOArr instance (or nil)
  //
  var myLocArr: LocDistIOArr(eltType, rank, idxType, stridable);

  var pid: int = -1; // privatized object id
//  proc initFilename(filename:string) {
//	  this.filename=filename;
//  }
}

//proc DistIODom.initFilename(filename:string) {
//	this._filename=filename;
//}

proc DistIOArr.dsiGetBaseDom() return dom;

proc DistIOArr.setup() {
  coforall localeIdx in dom.dist.targetLocDom {
    on dom.dist.targetLocales(localeIdx) {
      locArr(localeIdx) = new LocDistIOArr(eltType, rank, idxType, stridable, dom.locDoms(localeIdx), dom.locDoms(localeIdx));
      if this.locale == here then
        myLocArr = locArr(localeIdx);
    }
  }
}

proc DistIOArr.dsiSupportsPrivatization() param return true;

proc DistIOArr.dsiGetPrivatizeData() return 0;

proc DistIOArr.dsiPrivatize(privatizeData) {
  var privdom = chpl_getPrivatizedCopy(dom.type, dom.pid);
  var c = new DistIOArr(eltType=eltType, rank=rank, idxType=idxType, stridable=stridable, dom=privdom);
  c.locArr = locArr;
  for localeIdx in dom.dist.targetLocDom do
    if c.locArr(localeIdx).locale == here then
      c.myLocArr = c.locArr(localeIdx);
  return c;
}

//
// the global accessor for the array
//
// TODO: Do we need a global bounds check here or in idxToLocaleind?
//
proc DistIOArr.dsiAccess(i: idxType) var where rank == 1 {
  if myLocArr then /* TODO: reenable */ /* local */ {
    if myLocArr.indexDom.myStarts.member(i) then  // TODO: This could be beefed up; true for indices other than starts
      return myLocArr.this(i);
  }
  //  var loci = dom.dist.idxToLocaleInd(i);
  //  compilerError(typeToString(loci.type));
  //  var desc = locArr(loci);
  //  return locArr(loci)(i);
  return locArr(dom.dist.idxToLocaleInd(i))(i);
}

proc DistIOArr.dsiAccess(i: rank*idxType) var {
//   const myLocArr = locArr(here.id);
//   local {
//     if myLocArr.locDom.myStarts.member(i) then
//       return myLocArr.this(i);
//   }
  if rank == 1 {
    return dsiAccess(i(1));
  } else {
    return locArr(dom.dist.idxToLocaleInd(i))(i);
  }
}


iter DistIOArr.these() var {
  for i in dom do
    yield dsiAccess(i);
}

iter DistIOArr.these(param tag: iterKind) where tag == iterKind.leader {
  for yieldThis in dom.these(tag) do
    yield yieldThis;
}

iter DistIOArr.these(param tag: iterKind, followThis) var where tag == iterKind.follower {
  var myFollowThis: rank*range(idxType=idxType, stridable=stridable);
  var lowIdx: rank*idxType;

  for param i in 1..rank {
    var stride = dom.whole.dim(i).stride;
    var low = followThis(i).low * stride;
    var high = followThis(i).high * stride;
    myFollowThis(i) = (low..high by stride) + dom.whole.dim(i).low;
    lowIdx(i) = myFollowThis(i).low;
  }
  const myFollowThisDom = [(...myFollowThis)];

  //
  // TODO: The following is a buggy hack that will only work when we're
  // distributing across the entire Locales array.  I still think the
  // locArr/locDoms arrays should be associative over locale values.
  //
  const myLocArr = locArr(dom.dist.idxToLocaleInd(lowIdx));

  //
  // we don't own all the elements we're following
  //
  proc accessHelper(i) var {
//      if myLocArr.locale == here {
//	local {
//          if myLocArr.locDom.myStarts.member(i) then
//            return myLocArr.this(i);
//        }
//      }
    return dsiAccess(i);
  }
  for i in myFollowThisDom {
    yield accessHelper(i);
  }
}

//
// output array
//
proc DistIOArr.dsiSerialWrite(f: Writer) {
  if dom.dsiNumIndices == 0 then return;
  var i : rank*idxType;
  for dim in 1..rank do
    i(dim) = dom.dsiDim(dim).low;
  label next while true {
	  f.writeln("Elemento:",i);
    f.write(dsiAccess(i));
    if i(rank) <= (dom.dsiDim(rank).high - dom.dsiDim(rank).stride:idxType) {
      f.write(" ");
      i(rank) += dom.dsiDim(rank).stride:idxType;
    } else {
      for dim in 1..rank-1 by -1 {
        if i(dim) <= (dom.dsiDim(dim).high - dom.dsiDim(dim).stride:idxType) {
          i(dim) += dom.dsiDim(dim).stride:idxType;
          for dim2 in dim+1..rank {
            f.writeln();
            i(dim2) = dom.dsiDim(dim2).low;
          }
          continue next;
        }
      }
      break;
    }
  }
}

proc DistIOArr.dsiSlice(d: DistIODom) {
  var alias = new DistIOArr(eltType=eltType, rank=rank, idxType=idxType, stridable=d.stridable, dom=d, pid=pid);
  for i in dom.dist.targetLocDom {
    on dom.dist.targetLocales(i) {
      alias.locArr[i] = new LocDistIOArr(eltType=eltType, rank=rank, idxType=idxType, stridable=d.stridable, allocDom=locArr[i].allocDom, indexDom=d.locDoms[i], myElems=>locArr[i].myElems);
    }
  }

  return alias;
}

proc DistIOArr.dsiReindex(dom) {
  compilerError("reindexing not yet implemented for Block-Cyclic");
}

//proc DistIOArr.isDistIO() param {return true;}

////////////////////////////////////////////////////////////////////////////////
// DistIO Local Array Class
//
class LocDistIOArr {
  type eltType;
  param rank: int;
  type idxType;
  param stridable: bool;

  //
  // LEFT LINK: a reference to the local domain class for this array and locale
  //
  const allocDom: LocDistIODom(rank, idxType, stridable);
  const indexDom: LocDistIODom(rank, idxType, stridable);


  // STATE:

  //
  // the block of local array data
  //
  var myElems: [allocDom.myFlatInds] eltType;

  // TODO: need to be able to access these, but is this the right place?
  const blocksize: [1..rank] int = [d in 1..rank] allocDom.globDom.dist.blocksize(d);
  const low = allocDom.globDom.dsiLow;
  const locsize: [1..rank] int = [d in 1..rank] allocDom.globDom.dist.targetLocDom.dim(d).length;
  const numblocks: [1..rank] int = [d in 1..rank] (allocDom.myStarts.dim(d).length);

}


proc LocDistIOArr.mdInd2FlatInd(i: ?t, dim = 1) where t == idxType {
  //  writeln("blksize");
  const blksize = blocksize(dim);
  //  writeln("ind0");
  const ind0 = (i - low): int;
  //  writeln("blkNum");
  const blkNum = ind0 / (blksize * locsize(dim));
  //  writeln("blkOff");
  const blkOff = ind0 % blksize;
  //  writeln("returning");
  return  blkNum * blksize + blkOff;
}

proc LocDistIOArr.mdInd2FlatInd(i: ?t) where t == rank*idxType {
  if (false) {  // CMO
    var blkmults = * scan [d in 1..rank] blocksize(d);
    //    writeln("blkmults = ", blkmults);
    var numwholeblocks = 0;
    var blkOff = 0;
    for param d in rank..1 by -1 {
      const blksize = blocksize(d);
      const ind0 = (i(d) - low(d)): int;
      const blkNum = ind0 / (blksize * locsize(d));
      const blkDimOff = ind0 % blksize;
      if (d != rank) {
        numwholeblocks *= numblocks(rank-d);
        blkOff *= blkmults(rank-d);
      }
      numwholeblocks += blkNum;
      blkOff += blkDimOff;
    }
    return (numwholeblocks * blocksize(rank)) + blkOff;
  } else { // RMO
    //TODO: want negative scan: var blkmults = * scan [d in 1..rank] blocksize(d);
    var blkmults: [1..rank] int;
    blkmults(rank) = blocksize(rank);
    for d in rank-1..1 by -1 do
      blkmults(d) = blkmults(d+1) * blocksize(d);
    //    writeln("blkmults = ", blkmults);
    var numwholeblocks = 0;
    var blkOff = 0;
    for param d in 1..rank {
      const blksize = blocksize(d);
      const ind0 = (i(d) - low(d)): int;
      const blkNum = ind0 / (blksize * locsize(d));
      const blkDimOff = ind0 % blksize;
      if (d != 1) {
        numwholeblocks *= numblocks(rank-d+2);
        blkOff *= blkmults(rank-d+2);
      }
      numwholeblocks += blkNum;
      blkOff += blkDimOff;
      if (false && (i == (13,0) || i == (1,32))) {
          writeln(here.id, ":", "blksize = ", blksize);
          writeln(here.id, ":", "ind0 = ", ind0);
          writeln(here.id, ":", "blkNum = ", blkNum);
          writeln(here.id, ":", "blkDimOff = ", blkDimOff);
        }
    }

    if (false && (i == (13,0) || i == (1,32))) {
      writeln(here.id, ":", "numblocks = ", numblocks);
      writeln(here.id, ":", i, "->"); 
      writeln(here.id, ":","numwholeblocks = ", numwholeblocks);
      writeln(here.id, ":","blkOff = ", blkOff);
      writeln(here.id, ":","total = ", numwholeblocks * blkmults(1) + blkOff);
    }
    return (numwholeblocks * blkmults(1)) + blkOff;
  }
}

//
// the accessor for the local array -- assumes the index is local
//
proc LocDistIOArr.this(i) var {
  const flatInd = mdInd2FlatInd(i);
  //    writeln(i, "->", flatInd);
  return myElems(flatInd);
}

//
// output local array piece
//
proc LocDistIOArr.writeThis(x: Writer) {
  // note on this fails; see writeThisUsingOn.chpl
  x.write(myElems);
}

// sungeun: This doesn't appear to be used yet, so I left it, but it
//  might be useful to others.  Consider putting it in DSIUtil.chpl.

//
// helper function for blocking index ranges
//
proc _computeDistIO(waylo, numelems, lo, wayhi, numblocks, blocknum) {
  proc procToData(x, lo)
    return lo + (x:lo.type) + (x:real != x:int:real):lo.type;

  const blo =
    if blocknum == 0 then waylo
      else procToData((numelems:real * blocknum) / numblocks, lo);
  const bhi =
    if blocknum == numblocks - 1 then wayhi
      else procToData((numelems:real * (blocknum+1)) / numblocks, lo) - 1;

  return (blo, bhi);
}


