<?php

namespace App\Controller;

use App\Service\LockService;
use Symfony\Bridge\Twig\Attribute\Template;
use Symfony\Component\Routing\Attribute\Route;

class TestController
{
    #[Route('/', name: 'index')]
    #[Template('index.html.twig')]
    public function index(LockService $lockService): array
    {
        $lockService->createAndAcquireLockWithAutoRelease('mytest');

        return [];
    }
}