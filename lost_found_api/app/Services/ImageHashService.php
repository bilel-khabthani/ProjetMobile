<?php

namespace App\Services;

use GdImage;

/**
 * Empreinte perceptuelle d'une image (difference hash, 64 bits).
 *
 * L'image est reduite a 9x8 pixels en niveaux de gris : chaque pixel est
 * compare a son voisin de droite, ce qui produit 64 bits robustes aux
 * variations de taille, de compression et de luminosite. Deux photos du meme
 * objet donnent donc des empreintes proches meme si les fichiers different.
 */
class ImageHashService
{
    private const WIDTH = 9;

    private const HEIGHT = 8;

    /**
     * Calcule l'empreinte d'un fichier image. Retourne null si le fichier est
     * absent ou si GD ne parvient pas a le decoder.
     */
    public function hash(string $absolutePath): ?string
    {
        if (! is_file($absolutePath) || ! is_readable($absolutePath)) {
            return null;
        }

        $contents = file_get_contents($absolutePath);

        if ($contents === false) {
            return null;
        }

        return $this->hashContents($contents);
    }

    /** Calcule l'empreinte a partir des octets bruts d'une image. */
    public function hashContents(string $contents): ?string
    {
        $image = @imagecreatefromstring($contents);

        if ($image === false) {
            return null;
        }

        if (! imageistruecolor($image)) {
            imagepalettetotruecolor($image);
        }

        $small = imagescale($image, self::WIDTH, self::HEIGHT, IMG_BILINEAR_FIXED);

        if ($small === false) {
            imagedestroy($image);

            return null;
        }

        imagefilter($small, IMG_FILTER_GRAYSCALE);

        $bits = '';

        for ($y = 0; $y < self::HEIGHT; $y++) {
            for ($x = 0; $x < self::WIDTH - 1; $x++) {
                $left = $this->grayLevel($small, $x, $y);
                $right = $this->grayLevel($small, $x + 1, $y);
                $bits .= $left < $right ? '1' : '0';
            }
        }

        imagedestroy($small);
        imagedestroy($image);

        return $bits;
    }

    /**
     * Similarite entre deux empreintes (0-100), calculee par distance de
     * Hamming. Retourne null si l'une des deux photos est absente.
     */
    public function similarity(?string $first, ?string $second): ?int
    {
        if ($first === null || $second === null) {
            return null;
        }

        $length = min(strlen($first), strlen($second));

        if ($length === 0) {
            return null;
        }

        $differences = 0;

        for ($index = 0; $index < $length; $index++) {
            if ($first[$index] !== $second[$index]) {
                $differences++;
            }
        }

        return (int) round(100 - ($differences / $length) * 100);
    }

    private function grayLevel(GdImage $image, int $x, int $y): int
    {
        $color = imagecolorat($image, $x, $y);

        return ($color >> 16) & 0xFF;
    }
}
