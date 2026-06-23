allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ════════════════════════════════════════════════════════════
// [FIX] Places SDK nativo pineado a 3.5.0
// Fecha: 2026-06-22
// PROBLEMA: flutter_google_places_sdk_android 0.2.2 (única impl que admite el
//   plugin 0.4.3) usa getters (phoneNumber, placeTypes, userRatingsTotal) que
//   Places SDK 4.x+ eliminó; su gradle.properties pinea 5.1.1 → no compila.
// SOLUCIÓN: forzar Places 3.5.0 en TODOS los subproyectos (el force a nivel
//   :app no alcanza al módulo del plugin). 3.5.0 es la última 3.x con esos
//   getters y ya soporta initializeWithNewPlacesApiEnabled (Places API New).
// NOTA: excepción explícita a §7 (no overrides) autorizada por el desarrollador.
// ════════════════════════════════════════════════════════════
subprojects {
    configurations.all {
        resolutionStrategy {
            force("com.google.android.libraries.places:places:3.5.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
