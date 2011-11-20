var ALPHABET, ALPHA_ARROW, ALPHA_DIM, COL_ARROW, COL_BACKGROUND, COL_CURSOR, COL_DRAG_ORIGIN, COL_ERROR, COL_GRID, COL_NUMBER, COL_NUMBER_SET, CURSOR_DOWN, CURSOR_LEFT, CURSOR_RIGHT, CURSOR_SELECT, CURSOR_SELECT2, CURSOR_UP, CanvasPainter, Cell, Color, DIRECTION, DIR_OPPOSITE, GameParams, GameUI, IS_CURSOR_MOVE, IS_CURSOR_SELECT, IS_MOUSE_DOWN, LEFT_BUTTON, LEFT_DRAG, MIDDLE_BUTTON, MOUSE_DRAG, MOUSE_RELEASE, RIGHT_BUTTON, compare_heads, dir_angle, game_state, handle, head_meta, region_color, whichdir;
var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
if (typeof Math.seedrandom === "function") {
  Math.seedrandom('foo');
}
GameParams = (function() {
  function GameParams(w, h, force_corner_start) {
    this.w = w;
    this.h = h;
    this.force_corner_start = force_corner_start;
    if (this.w < 2 || this.h < 2) {
      throw 'W, H must at least be 2';
    }
    if (this.w === 2 && this.h === 2) {
      throw 'One must at least be 3';
    }
  }
  GameParams.prototype.new_game = function() {
    var headi, state, taili, x;
    for (x = 0; x <= 50; x++) {
      state = new game_state(this.w, this.h);
      while (true) {
        if (this.force_corner_start) {
          headi = 0;
          taili = state.n - 1;
        } else {
          while (true) {
            headi = Math.random_int(state.n);
            taili = Math.random_int(state.n);
            if (headi !== taili) {
              break;
            }
          }
        }
        if (state.new_game_fill(headi, taili)) {
          break;
        }
      }
      state.cells[headi].immutable = true;
      state.cells[taili].immutable = true;
      if (state.new_game_strip()) {
        state.strip_nums();
        state.update_numbers();
        state.check_completion(true);
        return state;
      }
    }
    throw 'Game generation failed.';
  };
  return GameParams;
})();
DIRECTION = [
  {
    x: 0,
    y: -1
  }, {
    x: 1,
    y: -1
  }, {
    x: 1,
    y: 0
  }, {
    x: 1,
    y: 1
  }, {
    x: 0,
    y: 1
  }, {
    x: -1,
    y: 1
  }, {
    x: -1,
    y: 0
  }, {
    x: -1,
    y: -1
  }
];
DIR_OPPOSITE = function(d) {
  return 0 | ((d + 4) % 8);
};
dir_angle = function(dir) {
  return 2.0 * Math.PI * dir / 8.0;
};
whichdir = function(fromx, fromy, tox, toy) {
  var dir, dx, dy, i, _len;
  dx = tox - fromx;
  dy = toy - fromy;
  if (dx && dy && Math.abs(dx) !== Math.abs(dy)) {
    return -1;
  }
  if (dx) {
    dx = 0 | (dx / Math.abs(dx));
  }
  if (dy) {
    dy = 0 | (dy / Math.abs(dy));
  }
  for (i = 0, _len = DIRECTION.length; i < _len; i++) {
    dir = DIRECTION[i];
    if (dx === dir.x && dy === dir.y) {
      return i;
    }
  }
  return -1;
};
Cell = (function() {
  function Cell() {
    this.dir = 0;
    this.num = 0;
    this.immutable = false;
    this.error = false;
    this.next = -1;
    this.prev = -1;
  }
  Cell.prototype.clone = function() {
    var c;
    c = new Cell();
    c.dir = this.dir;
    c.num = this.num;
    c.immutable = this.immutable;
    c.error = this.error;
    c.next = this.next;
    c.prev = this.prev;
    return c;
  };
  return Cell;
})();
game_state = (function() {
  function game_state(w, h) {
    var i;
    this.w = w;
    this.h = h;
    this.n = this.w * this.h;
    this.completed = this.used_solve = this.impossible = false;
    this.cells = (function() {
      var _ref, _results;
      _results = [];
      for (i = 0, _ref = this.n - 1; 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
        _results.push(new Cell());
      }
      return _results;
    }).call(this);
    this.dsf = new DisjointSetForest(this.n);
    this.numsi = snewn(this.n + 1);
    this.numsi.fill(-1);
  }
  game_state.prototype.clone = function() {
    var c, i, to, v, _len, _ref;
    to = new game_state(this.w, this.h);
    to.completed = this.completed;
    to.used_solve = this.used_solve;
    to.impossible = this.impossible;
    to.cells = (function() {
      var _i, _len, _ref, _results;
      _ref = this.cells;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        _results.push(c.clone());
      }
      return _results;
    }).call(this);
    to.dsf = this.dsf.clone();
    _ref = this.numsi;
    for (i = 0, _len = _ref.length; i < _len; i++) {
      v = _ref[i];
      to.numsi[i] = v;
    }
    return to;
  };
  game_state.prototype.in_grid = function(x, y) {
    return x >= 0 && x < this.w && y >= 0 && y < this.h;
  };
  game_state.prototype.is_real_number = function(num) {
    return num > 0 && num <= this.n;
  };
  game_state.prototype.region_colour = function(a) {
    return 0 | (a / (this.n + 1));
  };
  game_state.prototype.region_start = function(c) {
    return c * (this.n + 1);
  };
  game_state.prototype.whichdiri = function(fromi, toi) {
    return whichdir(0 | (fromi % this.w), 0 | (fromi / this.w), 0 | (toi % this.w), 0 | (toi / this.w));
  };
  game_state.prototype.ispointing = function(fromx, fromy, tox, toy) {
    var dir;
    dir = this.cells[fromy * this.w + fromx].dir;
    if (fromx === tox && fromy === toy) {
      return false;
    }
    if (this.cells[fromy * this.w + fromx].num === this.n) {
      return false;
    }
    while (true) {
      if (!this.in_grid(fromx, fromy)) {
        return false;
      }
      if (fromx === tox && fromy === toy) {
        return true;
      }
      fromx += DIRECTION[dir].x;
      fromy += DIRECTION[dir].y;
    }
    return null;
  };
  game_state.prototype.ispointingi = function(fromi, toi) {
    return this.ispointing(0 | (fromi % this.w), 0 | (fromi / this.w), 0 | (toi % this.w), 0 | (toi / this.w));
  };
  game_state.prototype.move_couldfit = function(num, d, x, y) {
    var cell, gap, i, n;
    i = y * this.w + x;
    cell = this.cells[i];
    n = num + d;
    gap = 0;
    while (this.is_real_number(n) && this.numsi[n] === -1) {
      n += d;
      gap++;
    }
    if (gap === 0) {
      return cell.num !== num + d;
    } else if (cell.prev === -1 && cell.next === -1) {
      return true;
    } else {
      return this.dsf.size(i) <= gap;
    }
  };
  game_state.prototype.isvalidmove = function(clever, fromx, fromy, tox, toy) {
    var from, nfrom, nto, to;
    if (!this.in_grid(fromx, fromy)) {
      return false;
    }
    if (!this.in_grid(tox, toy)) {
      return false;
    }
    if (!this.ispointing(fromx, fromy, tox, toy)) {
      return false;
    }
    from = fromy * this.w + fromx;
    to = toy * this.w + tox;
    nfrom = this.cells[from].num;
    nto = this.cells[to].num;
    if (nfrom === this.n && this.cells[from].immutable) {
      return false;
    }
    if (nto === 1 && this.cells[to].immutable) {
      return false;
    }
    if (this.dsf.canonify(from) === this.dsf.canonify(to)) {
      return false;
    }
    if (this.is_real_number(nfrom) && this.is_real_number(nto)) {
      return nfrom === nto - 1;
    } else if (clever && this.is_real_number(nfrom)) {
      return this.move_couldfit(nfrom, +1, tox, toy);
    } else if (clever && this.is_real_number(nto)) {
      return this.move_couldfit(nto, -1, fromx, fromy);
    } else {
      return true;
    }
  };
  game_state.prototype.makelink = function(from, to) {
    var c_from, c_to;
    c_from = this.cells[from];
    c_to = this.cells[to];
    if (c_from.next !== -1) {
      this.cells[c_from.next].prev = -1;
    }
    c_from.next = to;
    if (c_to.prev !== -1) {
      this.cells[c_to.prev].next = -1;
    }
    c_to.prev = from;
    return null;
  };
  game_state.prototype.unlink_cell = function(si) {
    var cell;
    cell = this.cells[si];
    if (cell.prev !== -1) {
      this.cells[cell.prev].next = -1;
      cell.prev = -1;
    }
    if (cell.next !== -1) {
      this.cells[cell.next].prev = -1;
      cell.next = -1;
    }
    return null;
  };
  game_state.prototype.strip_nums = function() {
    var c, _i, _len, _ref;
    _ref = this.cells;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      c = _ref[_i];
      if (!c.immutable) {
        c.num = 0;
      }
      c.next = c.prev = -1;
    }
    this.numsi.fill(-1);
    this.dsf.constructor(this.n);
    return null;
  };
  game_state.prototype.cell_adj = function(i) {
    var a, adjacent, dir, newi, sx, sy, x, y, _len;
    adjacent = [];
    sx = 0 | (i % this.w);
    sy = 0 | (i / this.w);
    for (a = 0, _len = DIRECTION.length; a < _len; a++) {
      dir = DIRECTION[a];
      x = sx;
      y = sy;
      while (true) {
        x += dir.x;
        y += dir.y;
        if (!this.in_grid(x, y)) {
          break;
        }
        newi = y * this.w + x;
        if (this.cells[newi].num === 0) {
          adjacent.push([newi, a]);
        }
      }
    }
    return adjacent;
  };
  game_state.prototype.new_game_fill = function(headi, taili) {
    var adir, adj, aidx, c, nfilled, _i, _len, _ref, _ref2, _ref3;
    _ref = this.cells;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      c = _ref[_i];
      c.num = 0;
    }
    this.cells[headi].num = 1;
    this.cells[taili].num = this.n;
    this.cells[taili].dir = 0;
    nfilled = 2;
    while (nfilled < this.n) {
      adj = this.cell_adj(headi);
      while (true) {
        if (adj.length === 0) {
          return false;
        }
        _ref2 = adj[Math.random_int(adj.length)], aidx = _ref2[0], adir = _ref2[1];
        this.cells[headi].dir = adir;
        this.cells[aidx].num = this.cells[headi].num + 1;
        nfilled++;
        headi = aidx;
        adj = this.cell_adj(headi);
        if (adj.length !== 1) {
          break;
        }
      }
      adj = this.cell_adj(taili);
      while (true) {
        if (adj.length === 0) {
          return false;
        }
        _ref3 = adj[Math.random_int(adj.length)], aidx = _ref3[0], adir = _ref3[1];
        this.cells[aidx].dir = DIR_OPPOSITE(adir);
        this.cells[aidx].num = this.cells[taili].num - 1;
        nfilled++;
        taili = aidx;
        adj = this.cell_adj(taili);
        if (adj.length !== 1) {
          break;
        }
      }
    }
    this.cells[headi].dir = this.whichdiri(headi, taili);
    return this.cells[headi].dir !== -1;
  };
  game_state.prototype.new_game_strip = function() {
    var copy, cps, j, scratch, solved, _i, _j, _len, _ref, _results;
    copy = this.clone();
    copy.strip_nums();
    if (copy.solve_state()) {
      return true;
    }
    scratch = (function() {
      _results = [];
      for (var _i = 0, _ref = this.n - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; 0 <= _ref ? _i++ : _i--){ _results.push(_i); }
      return _results;
    }).apply(this);
    scratch.shuffle();
    solved = __bind(function() {
      var cps, j, _j, _len;
      for (_j = 0, _len = scratch.length; _j < _len; _j++) {
        j = scratch[_j];
        if (copy.cells[j].num > 0 && copy.cells[j].num <= this.n) {
          continue;
        }
        copy.cells[j].num = this.cells[j].num;
        copy.cells[j].immutable = true;
        this.cells[j].immutable = true;
        copy.strip_nums();
        cps = copy.solve_state();
        if (cps) {
          copy = cps;
          return true;
        }
      }
      return false;
    }, this)();
    if (!solved) {
      return false;
    }
    for (_j = 0, _len = scratch.length; _j < _len; _j++) {
      j = scratch[_j];
      if (this.cells[j].immutable && this.cells[j].num !== 1 && this.cells[j].num !== this.n) {
        this.cells[j].immutable = false;
        copy = this.clone();
        copy.strip_nums();
        cps = copy.solve_state();
        if (!cps) {
          copy.cells[j].num = this.cells[j].num;
          this.cells[j].immutable = true;
        } else {
          copy = cps;
        }
      }
    }
    return true;
  };
  game_state.prototype.connect_numbers = function() {
    var cell, di, dni, i, _len, _ref;
    this.dsf.constructor(this.n);
    _ref = this.cells;
    for (i = 0, _len = _ref.length; i < _len; i++) {
      cell = _ref[i];
      if (cell.next !== -1) {
        di = this.dsf.canonify(i);
        dni = this.dsf.canonify(cell.next);
        if (di === dni) {
          this.impossible = 1;
        }
        this.dsf.merge(di, dni);
      }
    }
    return null;
  };
  game_state.prototype.lowest_start = function(heads) {
    var c, head, used, _i, _len, _ref;
    for (c = 1, _ref = this.n - 1; 1 <= _ref ? c <= _ref : c >= _ref; 1 <= _ref ? c++ : c--) {
      used = false;
      for (_i = 0, _len = heads.length; _i < _len; _i++) {
        head = heads[_i];
        if (this.region_colour(head.start) === c) {
          used = true;
          break;
        }
      }
      if (!used) {
        return c;
      }
    }
    return 0;
  };
  game_state.prototype.update_numbers = function() {
    var cell, head, heads, i, j, n, nnum, _i, _len, _len2, _ref, _ref2;
    this.numsi.fill(-1);
    _ref = this.cells;
    for (i = 0, _len = _ref.length; i < _len; i++) {
      cell = _ref[i];
      if (cell.immutable) {
        this.numsi[cell.num] = i;
      } else if (cell.prev === -1 && cell.next === -1) {
        cell.num = 0;
      }
    }
    this.connect_numbers();
    heads = (function() {
      var _len2, _ref2, _results;
      _ref2 = this.cells;
      _results = [];
      for (i = 0, _len2 = _ref2.length; i < _len2; i++) {
        cell = _ref2[i];
        if (!(cell.prev !== -1 || cell.next === -1)) {
          _results.push(new head_meta(this, i));
        }
      }
      return _results;
    }).call(this);
    heads.sort(compare_heads);
    if (heads.length > 0) {
      for (n = _ref2 = heads.length - 1; _ref2 <= 0 ? n <= 0 : n >= 0; _ref2 <= 0 ? n++ : n--) {
        if (n !== 0 && heads[n].start === heads[n - 1].start) {
          heads[n].start = this.region_start(this.lowest_start(heads));
          heads[n].preference = -1;
        } else if (!heads[n].preference) {
          heads[n].start = this.region_start(this.lowest_start(heads));
        }
      }
    }
    for (_i = 0, _len2 = heads.length; _i < _len2; _i++) {
      head = heads[_i];
      nnum = head.start;
      j = head.i;
      while (j !== -1) {
        if (!this.cells[j].immutable) {
          if (nnum > 0 && nnum <= this.n) {
            this.numsi[nnum] = j;
          }
          this.cells[j].num = nnum;
        }
        nnum++;
        j = this.cells[j].next;
      }
    }
    return null;
  };
  game_state.prototype.check_completion = function(mark_errors) {
    var c, cell, cellj, cellk, complete, error, j, n, _i, _j, _k, _len, _len2, _len3, _len4, _ref, _ref2, _ref3, _ref4, _ref5;
    error = false;
    if (mark_errors) {
      _ref = this.cells;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        c.error = false;
      }
    }
    _ref2 = this.cells;
    for (j = 0, _len2 = _ref2.length; j < _len2; j++) {
      cellj = _ref2[j];
      if (cellj.num > 0 && cellj.num <= this.n) {
        _ref3 = this.cells.slice(j + 1);
        for (_j = 0, _len3 = _ref3.length; _j < _len3; _j++) {
          cellk = _ref3[_j];
          if (cellk.num === cellj.num) {
            if (mark_errors) {
              cellj.error = true;
              cellk.error = true;
            }
            error = true;
          }
        }
      }
    }
    complete = true;
    for (n = 1, _ref4 = this.n - 1; 1 <= _ref4 ? n <= _ref4 : n >= _ref4; 1 <= _ref4 ? n++ : n--) {
      if (this.numsi[n] === -1 || this.numsi[n + 1] === -1) {
        complete = false;
      } else if (!this.ispointingi(this.numsi[n], this.numsi[n + 1])) {
        if (mark_errors) {
          this.cells[this.numsi[n]].error = true;
          this.cells[this.numsi[n + 1]].error = true;
        }
        error = true;
      } else {
        if (mark_errors) {
          this.makelink(this.numsi[n], this.numsi[n + 1]);
        }
      }
    }
    _ref5 = this.cells;
    for (_k = 0, _len4 = _ref5.length; _k < _len4; _k++) {
      cell = _ref5[_k];
      if (cell.num < 0 || (cell.num === 0 && (cell.next !== -1 || cell.prev !== -1))) {
        error = true;
        if (mark_errors) {
          cell.error = true;
        }
      }
    }
    if (error) {
      return false;
    }
    return complete;
  };
  game_state.prototype.execute_move = function(move) {
    var new_state;
    new_state = __bind(function() {
      var c, ex, ey, i, ret, si, sset, sx, sy, _ref;
      if (move[0] === 'L') {
        c = move[0], sx = move[1], sy = move[2], ex = move[3], ey = move[4];
        if (!this.isvalidmove(false, sx, sy, ex, ey)) {
          return null;
        }
        ret = this.clone();
        ret.makelink(sy * this.w + sx, ey * this.w + ex);
        return ret;
      } else if (move[0] === 'C' || move[0] === 'X') {
        c = move[0], sx = move[1], sy = move[2];
        if (!this.in_grid(sx, sy)) {
          return null;
        }
        si = sy * this.w + sx;
        if (this.cells[si].prev === -1 && this.cells[si].next === -1) {
          return null;
        }
        if (c === 'C') {
          ret = this.clone();
          ret.unlink_cell(si);
          return ret;
        } else {
          ret = this.clone();
          sset = this.region_colour(this.cells[si].num);
          for (i = 0, _ref = this.n - 1; 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
            if (this.cells[i].num !== 0 && sset === this.region_colour(this.cells[i].num)) {
              ret.unlink_cell(i);
            }
          }
          return ret;
        }
      } else if (move[0] === 'H') {
        return this.solve_state();
      }
    }, this)();
    if (new_state) {
      new_state.update_numbers();
      if (new_state.check_completion(true)) {
        new_state.completed = true;
      }
      return new_state;
    } else {
      return null;
    }
  };
  game_state.prototype.solve_single = function(copy) {
    var d, from, i, index, j, nlinks, poss, sx, sy, x, y, _ref, _ref2;
    nlinks = 0;
    from = (function() {
      var _ref, _results;
      _results = [];
      for (index = 1, _ref = this.n; 1 <= _ref ? index <= _ref : index >= _ref; 1 <= _ref ? index++ : index--) {
        _results.push(-1);
      }
      return _results;
    }).call(this);
    for (i = 0, _ref = this.n - 1; 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
      if (this.cells[i].next !== -1) {
        continue;
      }
      if (this.cells[i].num === this.n) {
        continue;
      }
      d = this.cells[i].dir;
      poss = -1;
      sx = x = 0 | (i % this.w);
      sy = y = 0 | (i / this.w);
      while (true) {
        x += DIRECTION[d].x;
        y += DIRECTION[d].y;
        if (!this.in_grid(x, y)) {
          break;
        }
        if (!this.isvalidmove(true, sx, sy, x, y)) {
          continue;
        }
        j = y * this.w + x;
        if (this.cells[j].prev !== -1) {
          continue;
        }
        if (this.cells[i].num > 0 && this.cells[j].num > 0 && this.cells[i].num <= this.n && this.cells[j].num <= this.n && this.cells[j].num === this.cells[i].num + 1) {
          poss = j;
          from[j] = i;
          break;
        }
        poss = poss === -1 ? j : -2;
        from[j] = from[j] === -1 ? i : -2;
      }
      if (poss === -2) {} else if (poss === -1) {
        copy.impossible = 1;
        return -1;
      } else {
        copy.makelink(i, poss);
        nlinks++;
      }
    }
    for (i = 0, _ref2 = this.n - 1; 0 <= _ref2 ? i <= _ref2 : i >= _ref2; 0 <= _ref2 ? i++ : i--) {
      if (this.cells[i].prev !== -1) {
        continue;
      }
      if (this.cells[i].num === 1) {
        continue;
      }
      x = 0 | (i % this.w);
      y = 0 | (i / this.w);
      if (from[i] === -1) {
        copy.impossible = 1;
        return -1;
      } else if (from[i] === -2) {} else {
        copy.makelink(from[i], i);
        nlinks++;
      }
    }
    return nlinks;
  };
  game_state.prototype.solve_state = function() {
    var copy, state;
    state = this.clone();
    copy = state.clone();
    while (true) {
      state.update_numbers();
      if (state.solve_single(copy)) {
        state = copy.clone();
        if (state.impossible) {
          break;
        }
      } else {
        break;
      }
    }
    state.update_numbers();
    if (state.impossible) {
      throw 'impossible';
    } else {
      if (state.check_completion(false)) {
        return state;
      } else {
        return null;
      }
    }
  };
  return game_state;
})();
head_meta = (function() {
  function head_meta(state, i) {
    var c, j, n, offset, ss, start_alternate, sz;
    this.i = i;
    this.start = null;
    this.sz = state.dsf.size(i);
    this.why = null;
    this.preference = 0;
    j = this.i;
    offset = 0;
    while (j !== -1) {
      if (state.cells[j].immutable) {
        ss = state.cells[j].num - offset;
        if (!this.preference) {
          this.start = ss;
          this.preference = 1;
          this.why = 'contains cell with immutable number';
        } else if (this.start !== ss) {
          state.impossible = 1;
        }
      }
      offset++;
      j = state.cells[j].next;
    }
    if (this.preference) {
      return;
    }
    if (state.cells[i].num === 0 && state.cells[state.cells[i].next].num > state.n) {
      this.start = state.region_start(state.region_colour(state.cells[state.cells[i].next].num));
      this.preference = 1;
      this.why = 'adding blank cell to head of numbered region';
    } else if (state.cells[i].num <= state.n) {
      this.start = 0;
      this.preference = 0;
      this.why = 'lowest available colour group';
    } else {
      c = state.region_colour(state.cells[i].num);
      n = 1;
      sz = state.dsf.size(i);
      j = i;
      while (state.cells[j].next !== -1) {
        j = state.cells[j].next;
        if (state.cells[j].num === 0 && state.cells[j].next === -1) {
          this.start = state.region_start(c);
          this.preference = 1;
          this.why = 'adding blank cell to end of numbered region';
          return;
        }
        if (state.region_colour(state.cells[j].num) === c) {
          n++;
        } else {
          start_alternate = state.region_start(state.region_colour(state.cells[j].num));
          if (n < (sz - n)) {
            this.start = start_alternate;
            this.preference = 1;
            this.why = 'joining two coloured regions, swapping to larger colour';
          } else {
            this.start = state.region_start(c);
            this.preference = 1;
            this.why = 'joining two coloured regions, taking largest';
          }
          return;
        }
      }
      if (c === 0) {
        this.start = 0;
        this.preference = 0;
      } else {
        this.start = state.region_start(c);
        this.preference = 1;
      }
      this.why = 'got to end of coloured region';
    }
  }
  return head_meta;
})();
compare_heads = function(ha, hb) {
  if (ha.preference && !hb.preference) {
    return -1;
  }
  if (hb.preference && !ha.preference) {
    return 1;
  }
  if (ha.start < hb.start) {
    return -1;
  }
  if (ha.start > hb.start) {
    return 1;
  }
  if (ha.sz > hb.sz) {
    return -1;
  }
  if (ha.sz < hb.sz) {
    return 1;
  }
  if (ha.i > hb.i) {
    return -1;
  }
  if (ha.i < hb.i) {
    return 1;
  }
  return 0;
};
LEFT_BUTTON = 1;
MIDDLE_BUTTON = 2;
RIGHT_BUTTON = 3;
LEFT_DRAG = 4;
MOUSE_DRAG = 5;
MOUSE_RELEASE = 7;
CURSOR_UP = 10;
CURSOR_DOWN = 11;
CURSOR_LEFT = 12;
CURSOR_RIGHT = 13;
CURSOR_SELECT = 14;
CURSOR_SELECT2 = 15;
IS_MOUSE_DOWN = function(m) {
  return m - LEFT_BUTTON <= RIGHT_BUTTON - LEFT_BUTTON;
};
IS_CURSOR_MOVE = function(m) {
  return m === CURSOR_UP || m === CURSOR_DOWN || m === CURSOR_RIGHT || m === CURSOR_LEFT;
};
IS_CURSOR_SELECT = function(m) {
  return m === CURSOR_SELECT || m === CURSOR_SELECT2;
};
GameUI = (function() {
  function GameUI() {
    this.cx = this.cy = 0;
    this.cshow = false;
    this.dragging = false;
    this.sx = this.sy = 0;
    this.dx = this.dy = 0;
    this.drag_is_from = false;
  }
  GameUI.prototype.interpret_cursor = function(state, ds, button) {
    var _ref, _ref2;
    if (IS_CURSOR_MOVE(button)) {
      switch (button) {
        case CURSOR_UP:
          this.cy = (this.cy - 1 + state.h) % state.h;
          break;
        case CURSOR_DOWN:
          this.cy = (this.cy + 1) % state.h;
          break;
        case CURSOR_LEFT:
          this.cx = (this.cx - 1 + state.w) % state.w;
          break;
        case CURSOR_RIGHT:
          this.cx = (this.cx + 1) % state.w;
      }
      this.cshow = true;
      if (this.dragging) {
        _ref = ds.cell_center(this.cx, this.cy), this.dx = _ref[0], this.dy = _ref[1];
      }
      return null;
    } else if (IS_CURSOR_SELECT(button)) {
      if (!this.cshow) {
        this.cshow = true;
      }
      if (this.dragging) {
        this.dragging = false;
        if (this.sx === this.cx && this.sy === this.cy) {
          return null;
        } else if (this.drag_is_from) {
          if (!state.isvalidmove(false, this.sx, this.sy, this.cx, this.cy)) {
            return null;
          } else {
            return ['L', this.sx, this.sy, this.cx, this.cy];
          }
        } else {
          if (!state.isvalidmove(false, this.cx, this.cy, this.sx, this.sy)) {
            return null;
          } else {
            return ['L', this.cx, this.cy, this.sx, this.sy];
          }
        }
      } else {
        this.dragging = true;
        this.sx = this.cx;
        this.sy = this.cy;
        _ref2 = ds.cell_center(this.cx, this.cy), this.dx = _ref2[0], this.dy = _ref2[1];
        this.drag_is_from = button === CURSOR_SELECT;
        return null;
      }
    }
  };
  GameUI.prototype.interpret_mouse_down = function(state, ds, mx, my, button) {
    var index, x, y, _ref;
    _ref = ds.cell_at(mx, my), x = _ref[0], y = _ref[1];
    index = y * state.w + x;
    if (this.cshow) {
      this.cshow = this.dragging = false;
    }
    if (!state.in_grid(x, y)) {
      return null;
    }
    if (button === LEFT_BUTTON) {
      if ((state.cells[index].num === state.n) && state.cells[index].immutable) {
        return null;
      }
    } else if (button === RIGHT_BUTTON) {
      if ((state.cells[index].num === 1) && state.cells[index].immutable) {
        return null;
      }
    }
    this.dragging = true;
    this.drag_is_from = button === LEFT_BUTTON;
    this.sx = x;
    this.sy = y;
    this.dx = mx;
    this.dy = my;
    this.cshow = false;
    return null;
  };
  GameUI.prototype.interpret_mouse_drag = function(mx, my) {
    if (this.dragging) {
      this.dx = mx;
      this.dy = my;
    }
    return null;
  };
  GameUI.prototype.interpret_mouse_drag_release = function(state, ds, mx, my) {
    var si, x, y, _ref;
    _ref = ds.cell_at(mx, my), x = _ref[0], y = _ref[1];
    if (this.sx === x && this.sy === y) {
      return null;
    } else if (!state.in_grid(x, y)) {
      si = this.sy * state.w + this.sx;
      if (state.cells[si].prev === -1 && state.cells[si].next === -1) {
        return null;
      } else {
        return [(this.drag_is_from ? 'C' : 'X'), this.sx, this.sy];
      }
    } else if (this.drag_is_from) {
      if (!state.isvalidmove(false, this.sx, this.sy, x, y)) {
        return null;
      } else {
        return ['L', this.sx, this.sy, x, y];
      }
    } else {
      if (!state.isvalidmove(false, x, y, this.sx, this.sy)) {
        return null;
      } else {
        return ['L', x, y, this.sx, this.sy];
      }
    }
  };
  GameUI.prototype.interpret_move = function(state, ds, mx, my, button) {
    var si;
    if (IS_CURSOR_MOVE(button)) {
      return this.interpret_cursor(state, ds, button);
    } else if (IS_CURSOR_SELECT(button)) {
      return this.interpret_cursor(state, ds, button);
    } else if (IS_MOUSE_DOWN(button)) {
      return this.interpret_mouse_down(state, ds, mx, my, button);
    } else if (button === MOUSE_DRAG) {
      return this.interpret_mouse_drag(mx, my);
    } else if (button === MOUSE_RELEASE && this.dragging) {
      this.dragging = false;
      return this.interpret_mouse_drag_release(state, ds, mx, my);
    } else if ((button === 'x' || button === 'X') && this.cshow) {
      si = this.cy * state.w + this.cx;
      if (state.cells[si].prev === -1 && state.cells[si].next === -1) {
        return null;
      } else {
        return [(button === 'x' ? 'C' : 'X'), this.cx, this.cy];
      }
    } else {
      return null;
    }
  };
  return GameUI;
})();
Color = net.brehaut.Color;
ALPHABET = 'abcdefghijklmnopqrstuvwxyz';
COL_BACKGROUND = '#eeeeee';
COL_GRID = '#cccccc';
COL_ARROW = '#000000';
COL_NUMBER_SET = '#0000ff';
COL_NUMBER = '#000000';
COL_CURSOR = '#000';
COL_DRAG_ORIGIN = 'blue';
COL_ERROR = 'red';
ALPHA_DIM = 0.2;
ALPHA_ARROW = 0.3;
region_color = function(set) {
  var hue, k, shift, step;
  hue = 0;
  step = 60;
  shift = step;
  for (k = 0; 0 <= set ? k <= set : k >= set; 0 <= set ? k++ : k--) {
    hue += step;
    if (hue >= 360) {
      hue -= 360;
      shift /= 2;
      hue += shift;
    }
  }
  return Color({
    hue: hue,
    saturation: 0.3,
    value: 1
  }).toCSS();
};
CanvasPainter = (function() {
  function CanvasPainter(dr) {
    this.dr = dr;
    null;
  }
  CanvasPainter.prototype.cell_center = function(cx, cy) {
    var x, y, _ref;
    _ref = this.cell_coord(cx, cy), x = _ref[0], y = _ref[1];
    return [x + this.tilesize / 2, y + this.tilesize / 2];
  };
  CanvasPainter.prototype.cell_coord = function(x, y) {
    return [x * this.tilesize + this.center_x, y * this.tilesize + this.center_y];
  };
  CanvasPainter.prototype.cell_at = function(x, y) {
    return [Math.floor((x + this.tilesize - this.center_x) / this.tilesize) - 1, Math.floor((y + this.tilesize - this.center_y) / this.tilesize) - 1];
  };
  CanvasPainter.prototype.draw_arrow = function(cx, cy, r, ang, cfill) {
    var p;
    this.dr.save();
    this.dr.translate(cx, cy);
    this.dr.rotate(ang);
    p = r * 0.4;
    this.dr.beginPath();
    this.dr.moveTo(0, -r);
    this.dr.lineTo(r, 0);
    this.dr.lineTo(p, 0);
    this.dr.lineTo(p, r);
    this.dr.lineTo(-p, r);
    this.dr.lineTo(-p, 0);
    this.dr.lineTo(-r, 0);
    this.dr.fillStyle = cfill;
    this.dr.fill();
    this.dr.restore();
    return null;
  };
  CanvasPainter.prototype.draw_star = function(cx, cy, rad, npoints, cfill) {
    var a, fun, n, r, _ref;
    this.dr.save();
    this.dr.translate(cx, cy);
    fun = 'moveTo';
    this.dr.beginPath();
    for (n = 0, _ref = npoints * 2 - 1; 0 <= _ref ? n <= _ref : n >= _ref; 0 <= _ref ? n++ : n--) {
      a = 2.0 * Math.PI * (n / (npoints * 2.0));
      r = 0 | (n % 2) ? rad / 2.0 : rad;
      this.dr[fun](r * Math.sin(a), -r * Math.cos(a));
      fun = 'lineTo';
    }
    this.dr.fillStyle = cfill;
    this.dr.fill();
    this.dr.restore();
    return null;
  };
  CanvasPainter.prototype.game_redraw = function(state, ui) {
    var acx, acy, ah, ang, arrow_in, arrow_out, arrowcol, aw, b, bgx, bgy, buf, cell, ch, cw, dir, empty, fx, fy, i, m, move, n, ox, oy, postdrop, region, s, set, tsx, tsy, x, y, _ref, _ref2, _ref3, _ref4, _ref5, _ref6;
    this.dr.canvas.width = this.dr.canvas.width;
    cw = this.dr.canvas.width;
    ch = this.dr.canvas.height;
    tsx = (cw * 0.8) / state.w;
    tsy = (ch * 0.8) / state.h;
    this.tilesize = Math.floor(Math.min(80, Math.min(tsx, tsy)));
    this.arrow_size = 7 * this.tilesize / 32;
    this.center_x = 0 | ((cw - state.w * this.tilesize) / 2);
    this.center_y = 0 | ((ch - state.h * this.tilesize) / 3);
    postdrop = null;
    if (ui.dragging) {
      move = ui.interpret_mouse_drag_release(state, this, ui.dx, ui.dy);
      if (move) {
        state = postdrop = state.execute_move(move);
      }
    }
    aw = this.tilesize * state.w;
    ah = this.tilesize * state.h;
    this.dr.fillStyle = COL_BACKGROUND;
    _ref = this.cell_coord(0, 0), bgx = _ref[0], bgy = _ref[1];
    this.dr.fillRect(bgx, bgy, aw, ah);
    for (x = 0, _ref2 = state.w - 1; 0 <= _ref2 ? x <= _ref2 : x >= _ref2; 0 <= _ref2 ? x++ : x--) {
      for (y = 0, _ref3 = state.h - 1; 0 <= _ref3 ? y <= _ref3 : y >= _ref3; 0 <= _ref3 ? y++ : y--) {
        this.dr.save();
        (_ref4 = this.dr).translate.apply(_ref4, this.cell_coord(x, y));
        cell = state.cells[x + y * state.w];
        arrowcol = COL_ARROW;
        if (ui.dragging) {
          if (x === ui.sx && y === ui.sy) {
            arrowcol = COL_DRAG_ORIGIN;
          } else if (ui.drag_is_from) {
            if (!state.ispointing(ui.sx, ui.sy, x, y)) {
              this.dr.globalAlpha = ALPHA_DIM;
            }
          } else if (!state.ispointing(x, y, ui.sx, ui.sy)) {
            this.dr.globalAlpha = ALPHA_DIM;
          }
        }
        arrow_out = cell.next !== -1;
        arrow_in = cell.prev !== -1;
        empty = cell.num === 0 && !arrow_out && !arrow_in;
        this.dr.fillStyle = empty ? COL_BACKGROUND : (region = state.region_colour(cell.num), cell.num <= 0 || region === 0 ? '#fff' : region_color(region));
        this.dr.fillRect(0, 0, this.tilesize, this.tilesize);
        this.dr.save();
        if (arrow_out) {
          this.dr.globalAlpha = Math.min(this.dr.globalAlpha, ALPHA_ARROW);
        }
        acx = this.tilesize / 2 + this.arrow_size;
        acy = this.tilesize / 2 + this.arrow_size;
        if (cell.num === state.n && cell.immutable) {
          this.draw_star(acx, acy, this.arrow_size, 5, arrowcol);
        } else {
          this.draw_arrow(acx, acy, this.arrow_size, dir_angle(cell.dir), arrowcol);
        }
        if (ui.cshow && x === ui.cx && y === ui.cy) {
          this.dr.save();
          this.dr.translate(0.5, 0.5);
          this.dr.beginPath();
          m = 1;
          s = this.arrow_size + 2 * m;
          b = s / 2;
          for (i = 0; i <= 3; i++) {
            this.dr.save();
            this.dr.translate(acx - m, acy - m);
            this.dr.rotate(i * Math.PI / 2);
            this.dr.moveTo(s, s - b);
            this.dr.lineTo(s, s);
            this.dr.lineTo(s - b, s);
            this.dr.restore();
          }
          this.dr.strokeStyle = COL_CURSOR;
          this.dr.stroke();
          this.dr.restore();
        }
        this.dr.restore();
        if (!arrow_in && cell.num !== 1) {
          this.dr.beginPath();
          this.dr.arc(this.tilesize / 2 - this.arrow_size, this.tilesize / 2 + this.arrow_size, this.arrow_size / 4, 0, 2 * Math.PI, false);
          this.dr.fillStyle = COL_ARROW;
          this.dr.fill();
        }
        this.dr.save();
        if ((arrow_in && arrow_out) || (cell.num === state.n) || (cell.num === 1)) {
          this.dr.globalAlpha = Math.min(this.dr.globalAlpha, ALPHA_ARROW);
        }
        if (!empty) {
          set = cell.num <= 0 ? 0 : state.region_colour(cell.num);
          this.dr.fillStyle = cell.immutable ? COL_NUMBER_SET : state.impossible || cell.num < 0 || cell.error ? COL_ERROR : COL_NUMBER;
          if (set === 0 || cell.num <= 0) {
            buf = "" + cell.num;
            this.dr.font = "bold " + (this.tilesize * 0.4) + "px sans-serif";
            this.dr.fillText(buf, this.tilesize * 0.1, this.tilesize * 0.4);
          } else {
            buf = '';
            while (set > 0) {
              set--;
              buf += ALPHABET[0 | (set % ALPHABET.length)];
              set = 0 | (set / 26);
            }
            n = 0 | (cell.num % (state.n + 1));
            if (n !== 0) {
              buf += "+" + n;
            }
            this.dr.font = "" + (this.tilesize * 0.35) + "px sans-serif";
            this.dr.fillText(buf, this.tilesize * 0.1, this.tilesize * 0.4);
          }
        }
        this.dr.restore();
        this.dr.globalAlpha = 1;
        this.dr.translate(0.5, 0.5);
        this.dr.strokeStyle = COL_GRID;
        this.dr.strokeRect(0, 0, this.tilesize, this.tilesize);
        this.dr.restore();
      }
    }
    if (ui.dragging) {
      if (postdrop != null) {
        if (ui.drag_is_from) {
          dir = state.cells[ui.sy * state.w + ui.sx].dir;
        } else {
          _ref5 = this.cell_at(ui.dx, ui.dy), fx = _ref5[0], fy = _ref5[1];
          dir = state.cells[fy * state.w + fx].dir;
        }
        ang = dir_angle(dir);
      } else {
        _ref6 = this.cell_center(ui.sx, ui.sy), ox = _ref6[0], oy = _ref6[1];
        ang = point_angle(ox, oy, ui.dx, ui.dy);
        if (!ui.drag_is_from) {
          ang += Math.PI;
        }
      }
      return this.draw_arrow(ui.dx, ui.dy, this.arrow_size, ang, COL_ARROW);
    }
  };
  null;
  return CanvasPainter;
})();
handle = function(e, l, f) {
  return e.addEventListener(l, f, false);
};
handle(window, 'load', function() {
  var again_button, canvas, corner_start, ctx, current_state, draw, ds, fail, make_move, mouse_is_down, params, play_button, redo_move, setup, setup_height, setup_width, start_game, states, ui, undo_move, won, x, y;
  ui = new GameUI();
  canvas = document.getElementById('game');
  canvas.style.display = 'block';
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  ctx = canvas.getContext('2d');
  ds = new CanvasPainter(ctx);
  setup = document.getElementById('setup');
  setup_width = document.getElementById('width');
  setup_height = document.getElementById('height');
  play_button = document.getElementById('play');
  won = document.getElementById('won');
  again_button = document.getElementById('again');
  corner_start = document.getElementById('corner_start');
  fail = document.getElementById('fail');
  fail.style.display = 'none';
  handle(again_button, 'click', function() {
    won.style.display = 'none';
    return setup.style.display = 'block';
  });
  setup.style.display = 'block';
  params = new GameParams(6, 6, true);
  states = [];
  current_state = 0;
  draw = function() {
    if ((0 <= current_state && current_state < states.length)) {
      return ds.game_redraw(states[current_state], ui);
    }
  };
  start_game = function() {
    var c, h, w;
    w = 0 | +setup_width.value;
    h = 0 | +setup_height.value;
    c = !!+corner_start.value;
    if ((3 <= w && w <= 50) && (3 <= h && h <= 50)) {
      params = new GameParams(w, h, c);
      states = [params.new_game()];
      current_state = 0;
      return draw();
    }
  };
  handle(play_button, 'click', function() {
    start_game();
    return setup.style.display = 'none';
  });
  x = y = 0;
  make_move = function(button) {
    var mov, new_state;
    if ((0 <= current_state && current_state < states.length) && !states[current_state].completed) {
      mov = ui.interpret_move(states[current_state], ds, x, y, button);
      if (mov) {
        new_state = states[current_state].execute_move(mov);
        states = states.slice(0, (current_state + 1) || 9e9);
        states.push(new_state);
        current_state++;
      }
      draw();
      if (states[current_state].completed) {
        return won.style.display = 'block';
      }
    }
  };
  undo_move = function() {
    if (current_state > 0) {
      current_state--;
      draw();
      return true;
    } else {
      return false;
    }
  };
  redo_move = function() {
    if (current_state < states.length - 1) {
      current_state++;
      draw();
      return true;
    } else {
      return false;
    }
  };
  handle(window, 'keydown', function(event) {
    switch (event.keyCode) {
      case 37:
      case 65:
        make_move(CURSOR_LEFT);
        return event.preventDefault();
      case 38:
      case 87:
        make_move(CURSOR_UP);
        return event.preventDefault();
      case 39:
      case 68:
        make_move(CURSOR_RIGHT);
        return event.preventDefault();
      case 40:
      case 83:
        make_move(CURSOR_DOWN);
        return event.preventDefault();
      case 32:
        make_move(CURSOR_SELECT);
        return event.preventDefault();
      case 13:
        make_move(CURSOR_SELECT2);
        return event.preventDefault();
      case 85:
        if (undo_move()) {
          return event.preventDefault();
        }
        break;
      case 82:
        if (redo_move()) {
          return event.preventDefault();
        }
    }
  });
  handle(canvas, 'contextmenu', function(event) {
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation();
    }
    return event.preventDefault();
  });
  mouse_is_down = false;
  handle(canvas, 'mousedown', function(event) {
    mouse_is_down = true;
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation();
    }
    event.preventDefault();
    x = event.clientX;
    y = event.clientY;
    switch (event.button) {
      case 0:
        return make_move(LEFT_BUTTON);
      case 1:
        return make_move(MIDDLE_BUTTON);
      case 2:
        return make_move(RIGHT_BUTTON);
    }
  });
  handle(canvas, 'mouseup', function(event) {
    mouse_is_down = false;
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation();
    }
    event.preventDefault();
    x = event.clientX;
    y = event.clientY;
    return make_move(MOUSE_RELEASE);
  });
  handle(window, 'mouseup', function(event) {
    mouse_is_down = false;
    return make_move(MOUSE_RELEASE);
  });
  handle(canvas, 'mousemove', function(event) {
    if (mouse_is_down) {
      event.preventDefault();
      x = event.clientX;
      y = event.clientY;
      return make_move(MOUSE_DRAG);
    }
  });
  handle(window, 'resize', function(event) {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    return draw();
  });
  return draw();
});