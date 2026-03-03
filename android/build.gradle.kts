// Repositories are centrally managed via settings.gradle.kts (dependencyResolutionManagement)

plugins {
    id("vkid.manifest.placeholders") version "1.1.0" apply true
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Подавляем предупреждения об устаревших опциях Java для всех подпроектов
    afterEvaluate {
        tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
            options.compilerArgs.add("-Xlint:-options")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// VK ID placeholders конфигурация - должна быть в корневом проекте
// Конфигурация также добавлена в local.properties как альтернатива
vkidManifestPlaceholders {
    vkidRedirectHost = "vk.com"
    vkidRedirectScheme = "vk54063347"
    vkidClientId = "54063347"
    vkidClientSecret = "psZy9zAddNAsilR9euiI"
}
