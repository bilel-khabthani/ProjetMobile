<?php
$it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(__DIR__ . '/vendor'));
$count = 0;
foreach ($it as $f) {
    if ($f->isFile() && $f->getExtension() === 'php') {
        $c = file_get_contents($f->getPathname());
        if (preg_match('/(public|protected|private)\s+const\s+(int|string|bool|float|array)\s+/', $c)) {
            $c = preg_replace('/(public|protected|private)\s+const\s+(int|string|bool|float|array)\s+/', '$1 const ', $c);
            file_put_contents($f->getPathname(), $c);
            $count++;
        }
    }
}
echo "Fixed $count files.\n";

