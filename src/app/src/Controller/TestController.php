<?php

namespace App\Controller;

use App\Service\LockService;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Symfony\Component\Routing\Attribute\Route;

class TestController
{
    #[Route('/', name: 'home_page')]
    public function index(LockService $lockService): Response
    {
        $lockService->createAndAcquireLockWithAutoRelease('mytest');

        return new Response('Hello World!');
//        dd($request);
    }
}