allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugins de Flutter que todavía compilan contra una versión vieja de Android (por ejemplo file_picker,
// contra la 34): flutter_plugin_android_lifecycle pide compilar contra la 36 o más nueva. Solo cambia
// contra qué versión se COMPILA el plugin; no cambia en qué celulares se puede instalar (eso es minSdk).
subprojects {
    afterEvaluate {
        plugins.withId("com.android.library") {
            val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if ((android.compileSdkVersion?.substringAfter("android-")?.toIntOrNull() ?: 0) < 36) {
                android.compileSdkVersion(36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
