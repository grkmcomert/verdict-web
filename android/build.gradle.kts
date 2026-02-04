allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // --- İŞTE O MEŞHUR YAMA (KOTLIN VERSİYONU) ---
    // Bu kod, namespace'i eksik olan kütüphanelere (webview_cookie_manager gibi)
    // otomatik olarak namespace atar.
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            try {
                configure<com.android.build.gradle.BaseExtension> {
                    if (namespace == null) {
                        namespace = project.group.toString()
                    }
                }
            } catch (e: Exception) {
                // Hata olursa yut, önemli değil.
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