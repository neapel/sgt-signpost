var DisjointSetForest;
DisjointSetForest = (function() {
  function DisjointSetForest(size) {
    var i;
    this.dsf = (function() {
      var _results;
      _results = [];
      for (i = 1; 1 <= size ? i <= size : i >= size; 1 <= size ? i++ : i--) {
        _results.push(6);
      }
      return _results;
    })();
  }
  DisjointSetForest.prototype.clone = function() {
    var index, r, value, _len, _ref;
    r = new DisjointSetForest(this.size);
    _ref = this.dsf;
    for (index = 0, _len = _ref.length; index < _len; index++) {
      value = _ref[index];
      r.dsf[index] = value;
    }
    return r;
  };
  DisjointSetForest.prototype.canonify = function(index) {
    return this.extended_canonify(index, null)[0];
  };
  DisjointSetForest.prototype.merge = function(v1, v2) {
    this.extended_merge(v1, v2, false);
    return null;
  };
  DisjointSetForest.prototype.size = function(index) {
    return this.dsf[this.canonify(index)] >> 2;
  };
  DisjointSetForest.prototype.extended_canonify = function(index) {
    var canonical_index, inverse, inverse_return, nextindex, nextinverse, start_index;
    start_index = index;
    inverse = 0;
    while ((this.dsf[index] & 2) === 0) {
      inverse ^= this.dsf[index] & 1;
      index = this.dsf[index] >> 2;
    }
    canonical_index = index;
    inverse_return = inverse;
    index = start_index;
    while (index !== canonical_index) {
      nextindex = this.dsf[index] >> 2;
      nextinverse = inverse ^ (this.dsf[index] & 1);
      this.dsf[index] = (canonical_index << 2) | inverse;
      inverse = nextinverse;
      index = nextindex;
    }
    return [index, inverse_return];
  };
  DisjointSetForest.prototype.extended_merge = function(v1, v2, inverse) {
    var i1, i2, _ref, _ref2, _ref3, _ref4;
    _ref = this.extended_canonify(v1), v1 = _ref[0], i1 = _ref[1];
    inverse ^= i1;
    _ref2 = this.extended_canonify(v2), v2 = _ref2[0], i2 = _ref2[1];
    inverse ^= i2;
    if (v1 !== v2) {
      if (v1 > v2) {
        _ref3 = [v2, v1], v1 = _ref3[0], v2 = _ref3[1];
      }
      this.dsf[v1] += (this.dsf[v2] >> 2) << 2;
      this.dsf[v2] = (v1 << 2) | !!inverse;
    }
    _ref4 = this.extended_canonify(v2), v2 = _ref4[0], i2 = _ref4[1];
    return null;
  };
  return DisjointSetForest;
})();