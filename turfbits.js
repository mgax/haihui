// Code from turf.js, https://github.com/Turfjs, licensed as MIT

window.turf = {};

turf.distance = function(point1, point2, units){
  var coordinates1 = point1.geometry.coordinates;
  var coordinates2 = point2.geometry.coordinates;

  var dLat = toRad(coordinates2[1] - coordinates1[1]);
  var dLon = toRad(coordinates2[0] - coordinates1[0]);
  var lat1 = toRad(coordinates1[1]);
  var lat2 = toRad(coordinates2[1]);
  var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
          Math.sin(dLon/2) * Math.sin(dLon/2) * Math.cos(lat1) * Math.cos(lat2);
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

  var R;
  switch(units){
    case 'miles':
      R = 3960;
      break;
    case 'kilometers':
      R = 6373;
      break;
    case 'degrees':
      R = 57.2957795;
      break;
    case 'radians':
      R = 1;
      break;
    case undefined:
      R = 6373;
      break;
    default:
      throw new Error('unknown option given to "units"');
  }

  var distance = R * c;
  return distance;

  function toRad(degree) {
    return degree * Math.PI / 180;
  }
};

turf.point = function(coordinates, properties) {
  var isArray = Array.isArray || function(arg) {
    return Object.prototype.toString.call(arg) === '[object Array]';
  };

  if (!isArray(coordinates)) throw new Error('Coordinates must be an array');
  if (coordinates.length < 2) throw new Error('Coordinates must be at least 2 numbers long');
  return {
    type: "Feature",
    geometry: {
      type: "Point",
      coordinates: coordinates
    },
    properties: properties || {}
  };
};


turf.bearing = function (point1, point2) {
    var coordinates1 = point1.geometry.coordinates;
    var coordinates2 = point2.geometry.coordinates;

    var lon1 = toRad(coordinates1[0]);
    var lon2 = toRad(coordinates2[0]);
    var lat1 = toRad(coordinates1[1]);
    var lat2 = toRad(coordinates2[1]);
    var a = Math.sin(lon2 - lon1) * Math.cos(lat2);
    var b = Math.cos(lat1) * Math.sin(lat2) -
        Math.sin(lat1) * Math.cos(lat2) * Math.cos(lon2 - lon1);

    var bearing = toDeg(Math.atan2(a, b));

    return bearing;

    function toRad(degree) {
        return degree * Math.PI / 180;
    }

    function toDeg(radian) {
        return radian * 180 / Math.PI;
    }
};

turf.destination = function (point1, distance, bearing, units) {
    var coordinates1 = point1.geometry.coordinates;
    var longitude1 = toRad(coordinates1[0]);
    var latitude1 = toRad(coordinates1[1]);
    var bearing_rad = toRad(bearing);

    var R = 0;
    switch (units) {
    case 'miles':
        R = 3960;
        break
    case 'kilometers':
        R = 6373;
        break
    case 'degrees':
        R = 57.2957795;
        break
    case 'radians':
        R = 1;
        break
    }

    var latitude2 = Math.asin(Math.sin(latitude1) * Math.cos(distance / R) +
        Math.cos(latitude1) * Math.sin(distance / R) * Math.cos(bearing_rad));
    var longitude2 = longitude1 + Math.atan2(Math.sin(bearing_rad) * Math.sin(distance / R) * Math.cos(latitude1),
        Math.cos(distance / R) - Math.sin(latitude1) * Math.sin(latitude2));

    return turf.point([toDeg(longitude2), toDeg(latitude2)]);

    function toRad(degree) {
        return degree * Math.PI / 180;
    }

    function toDeg(rad) {
        return rad * 180 / Math.PI;
    }
};

turf.along = function (line, dist, units) {
  var coords;
  if(line.type === 'Feature') coords = line.geometry.coordinates;
  else if(line.type === 'LineString') coords = line.geometry.coordinates;
  else throw new Error('input must be a LineString Feature or Geometry');

  var travelled = 0;
  for(var i = 0; i < coords.length; i++) {
    if (dist >= travelled && i === coords.length - 1) break;
    else if(travelled >= dist) {
      var overshot = dist - travelled;
      if(!overshot) return turf.point(coords[i]);
      else {
        var direction = turf.bearing(turf.point(coords[i]), turf.point(coords[i-1])) - 180;
        var interpolated = turf.destination(turf.point(coords[i]), overshot, direction, units);
        return interpolated;
      }
    }
    else {
      travelled += turf.distance(turf.point(coords[i]), turf.point(coords[i+1]), units);
    }
  }
  return turf.point(coords[coords.length - 1]);
};

turf.lineDistance = function (line, units) {
  var coords;
  if(line.type === 'Feature') coords = line.geometry.coordinates;
  else if(line.type === 'LineString') coords = line.geometry.coordinates;
  else throw new Error('input must be a LineString Feature or Geometry');

  var travelled = 0;
  for(var i = 0; i < coords.length - 1; i++) {
    travelled += turf.distance(turf.point(coords[i]), turf.point(coords[i+1]), units);
  }
  return travelled;
};
