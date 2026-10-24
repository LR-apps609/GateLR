package app.gatelr.core

import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

object Geometry {
    /** Il punto è dentro il perimetro? (ray casting) */
    fun inside(p: List<Coordinate>, lat: Double, lon: Double): Boolean {
        var inside = false
        var j = p.size - 1
        for (i in p.indices) {
            val a = p[i]; val b = p[j]
            if ((a.lat > lat) != (b.lat > lat) && lon < (b.lon - a.lon) * (lat - a.lat) / (b.lat - a.lat) + a.lon) inside = !inside
            j = i
        }
        return inside
    }

    fun meters(a: Coordinate, b: Coordinate): Double {
        val k = cos(a.lat * Math.PI / 180)
        return hypot((a.lat - b.lat) * 111_000, (a.lon - b.lon) * 111_000 * k)
    }

    private fun project(p: Coordinate, a: Coordinate, b: Coordinate): Pair<Double, Double> {
        val k = cos(p.lat * Math.PI / 180)
        val ax = (a.lon - p.lon) * 111_000 * k; val ay = (a.lat - p.lat) * 111_000
        val bx = (b.lon - p.lon) * 111_000 * k; val by = (b.lat - p.lat) * 111_000
        val dx = bx - ax; val dy = by - ay
        val len2 = dx * dx + dy * dy
        val t = if (len2 == 0.0) 0.0 else max(0.0, min(1.0, -(ax * dx + ay * dy) / len2))
        return hypot(ax + t * dx, ay + t * dy) to t
    }

    /** Distanza in metri da una linea (dal tratto più vicino) */
    fun distanceToPath(p: Coordinate, path: List<Coordinate>): Double {
        if (path.size < 2) return path.firstOrNull()?.let { meters(p, it) } ?: Double.POSITIVE_INFINITY
        return path.zipWithNext { a, b -> project(p, a, b).first }.min()
    }

    /** I metri che restano dal punto della linea più vicino fino alla fine */
    fun remaining(p: Coordinate, path: List<Coordinate>): Double {
        if (path.size < 2) return path.firstOrNull()?.let { meters(p, it) } ?: 0.0
        var bestI = 0; var bestD = Double.POSITIVE_INFINITY; var bestT = 0.0
        for (i in 0 until path.size - 1) {
            val (d, t) = project(p, path[i], path[i + 1])
            if (d < bestD) { bestD = d; bestI = i; bestT = t }
        }
        var total = meters(path[bestI], path[bestI + 1]) * (1 - bestT)
        for (j in bestI + 1 until path.size - 1) total += meters(path[j], path[j + 1])
        return total
    }

    /** «350 m», «1,2 km» */
    fun distanceText(m: Double): String {
        val r = if (m >= 1_000) Math.round(m / 100) * 100.0 else if (m >= 100) Math.round(m / 50) * 50.0 else Math.round(m / 10) * 10.0
        return if (r >= 1_000) String.format(java.util.Locale.getDefault(), "%.1f km", r / 1000) else "${r.toInt()} m"
    }
}
