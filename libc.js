var assert, memcpy, memset, point_angle, qsort, random_upto, snewn;
assert = function(ex) {
  if (!ex) {
    throw 'assertion failed';
  }
};
memset = function(array, value, length) {
  var i, _ref, _results;
  _results = [];
  for (i = 0, _ref = length - 1; 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
    _results.push(array[i] = value);
  }
  return _results;
};
memcpy = function(to, from, length) {
  var i, _ref, _results;
  _results = [];
  for (i = 0, _ref = length - 1; 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
    _results.push(to[i] = from[i]);
  }
  return _results;
};
snewn = function(length, type) {
  var index, _ref, _ref2, _results, _results2;
  if (type == null) {
    type = null;
  }
  if (type != null) {
    _results = [];
    for (index = 0, _ref = length - 1; 0 <= _ref ? index <= _ref : index >= _ref; 0 <= _ref ? index++ : index--) {
      _results.push(new type());
    }
    return _results;
  } else {
    _results2 = [];
    for (index = 0, _ref2 = length - 1; 0 <= _ref2 ? index <= _ref2 : index >= _ref2; 0 <= _ref2 ? index++ : index--) {
      _results2.push(0);
    }
    return _results2;
  }
};
qsort = function(array, length, cmp) {
  return array.sort(cmp);
};
Math.random_int = function(limit) {
  return this.floor(this.random() * limit);
};
random_upto = function(random_state, limit) {
  return Math.random_int(limit);
};
Array.prototype.shuffle = function() {
  var i, j, _ref, _ref2;
  for (i = _ref = this.length - 1; i >= 1; i += -1) {
    j = Math.random_int(i + 1);
    _ref2 = [this[i], this[j]], this[j] = _ref2[0], this[i] = _ref2[1];
  }
  return null;
};
Array.prototype.fill = function(value) {
  var index, _len, _v;
  for (index = 0, _len = this.length; index < _len; index++) {
    _v = this[index];
    this[index] = value;
  }
  return null;
};
point_angle = function(ox, oy, dx, dy) {
  var offset, tana, xdiff, ydiff;
  xdiff = Math.abs(ox - dx);
  ydiff = Math.abs(oy - dy);
  if (xdiff === 0) {
    if (oy > dy) {
      return 0;
    } else {
      return Math.PI;
    }
  } else if (ydiff === 0) {
    if (ox > dx) {
      return 3 * Math.PI / 2;
    } else {
      return Math.PI / 2;
    }
  } else {
    if (dx > ox && dy < oy) {
      tana = xdiff / ydiff;
      offset = 0;
    } else if (dx > ox && dy > oy) {
      tana = ydiff / xdiff;
      offset = Math.PI / 2;
    } else if (dx < ox && dy > oy) {
      tana = xdiff / ydiff;
      offset = Math.PI;
    } else {
      tana = ydiff / xdiff;
      offset = 3 * Math.PI / 2;
    }
    return Math.atan(tana) + offset;
  }
};